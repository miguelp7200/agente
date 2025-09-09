# Frontend Timeout Configuration for ZIP Handling

## Problem
Your frontend is timing out after 5+ minutes when the backend processes large ZIP requests with many PDFs (like 44 PDFs in your case).

## Solution 1: Increase Frontend Timeout

Create this configuration in your Next.js frontend:

### File: `config/api.ts`
```typescript
// API Configuration for ZIP handling
export const API_CONFIG = {
  // Timeout for regular requests
  DEFAULT_TIMEOUT: 2 * 60 * 1000, // 2 minutes
  
  // Extended timeout for ZIP creation requests
  ZIP_TIMEOUT: 15 * 60 * 1000, // 15 minutes
  
  // Backend URL
  BACKEND_URL: process.env.NEXT_PUBLIC_BACKEND_URL || 'https://invoice-backend-yuhrx5x2ra-uc.a.run.app',
  
  // Request headers
  HEADERS: {
    'Content-Type': 'application/json',
  }
};

// Detect if request might generate a ZIP
export function isZipRequest(message: string): boolean {
  const zipTriggers = [
    'las 10 facturas',
    'todas las facturas',
    'facturas del',
    'facturas de ',
    'mes de',
    'año',
    'diciembre',
    'octubre',
    'noviembre'
  ];
  
  return zipTriggers.some(trigger => 
    message.toLowerCase().includes(trigger)
  );
}
```

### File: `app/api/chat/route.ts` (Updated)
```typescript
import { API_CONFIG, isZipRequest } from '@/config/api';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { message } = body;
    
    // Detect if this might be a ZIP request
    const mightGenerateZip = isZipRequest(message);
    const timeout = mightGenerateZip ? API_CONFIG.ZIP_TIMEOUT : API_CONFIG.DEFAULT_TIMEOUT;
    
    console.log(`🔍 Request type: ${mightGenerateZip ? 'ZIP-enabled' : 'standard'}`);
    console.log(`⏱️ Timeout set to: ${timeout / 1000} seconds`);
    
    // Create abort controller with appropriate timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);
    
    try {
      const response = await fetch(`${API_CONFIG.BACKEND_URL}/run`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          ...API_CONFIG.HEADERS,
        },
        body: JSON.stringify(payload),
        signal: controller.signal
      });
      
      clearTimeout(timeoutId);
      
      if (!response.ok) {
        throw new Error(`Backend responded with ${response.status}`);
      }
      
      const result = await response.json();
      return Response.json(result);
      
    } catch (error) {
      clearTimeout(timeoutId);
      
      if (error.name === 'AbortError') {
        console.error(`❌ Request timed out after ${timeout / 1000} seconds`);
        return Response.json(
          { 
            error: `Request timed out. ZIP creation with many files can take up to ${timeout / 60000} minutes.`,
            timeout: true 
          }, 
          { status: 408 }
        );
      }
      
      throw error;
    }
    
  } catch (error) {
    console.error('❌ Error in API route:', error);
    return Response.json(
      { error: 'Internal server error' }, 
      { status: 500 }
    );
  }
}
```

### File: `components/chat/ChatInterface.tsx` (Updated)
```typescript
// Add loading state for ZIP creation
const [isCreatingZip, setIsCreatingZip] = useState(false);

const sendMessage = async (message: string) => {
  // Detect ZIP requests
  const mightGenerateZip = isZipRequest(message);
  
  if (mightGenerateZip) {
    setIsCreatingZip(true);
    // Show user that ZIP creation might take time
    addMessage({
      id: Date.now().toString(),
      content: "⏳ Detectado: esta consulta puede generar un archivo ZIP con múltiples facturas. Esto puede tomar varios minutos...",
      role: 'assistant',
      timestamp: new Date(),
    });
  }
  
  try {
    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message }),
    });
    
    if (response.status === 408) {
      // Handle timeout specifically
      const errorData = await response.json();
      addMessage({
        id: Date.now().toString(),
        content: `⚠️ ${errorData.error}\n\nIntenta nuevamente o divide tu consulta en partes más pequeñas.`,
        role: 'assistant',
        timestamp: new Date(),
      });
      return;
    }
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    
    const data = await response.json();
    addMessage({
      id: Date.now().toString(),
      content: data.content || data.message,
      role: 'assistant',
      timestamp: new Date(),
    });
    
  } catch (error) {
    console.error('Error sending message:', error);
    addMessage({
      id: Date.now().toString(),
      content: "❌ Error al procesar tu consulta. Por favor intenta nuevamente.",
      role: 'assistant',
      timestamp: new Date(),
    });
  } finally {
    setIsCreatingZip(false);
  }
};
```

## Solution 2: User Experience Improvements

### File: `components/ui/LoadingSpinner.tsx`
```typescript
interface LoadingSpinnerProps {
  isZipCreation?: boolean;
}

export function LoadingSpinner({ isZipCreation = false }: LoadingSpinnerProps) {
  return (
    <div className="flex items-center space-x-2">
      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
      <span className="text-sm text-gray-600">
        {isZipCreation 
          ? "Creando archivo ZIP con múltiples facturas..." 
          : "Procesando consulta..."
        }
      </span>
      {isZipCreation && (
        <span className="text-xs text-gray-500">
          (Esto puede tomar hasta 15 minutos)
        </span>
      )}
    </div>
  );
}
```

## Solution 3: Progressive Enhancement (Optional)

For even better UX, consider implementing progress polling:

### File: `hooks/useZipProgress.ts`
```typescript
export function useZipProgress() {
  const [progress, setProgress] = useState<{
    status: 'idle' | 'creating' | 'completed' | 'error';
    message: string;
    progress?: number;
  }>({ status: 'idle', message: '' });
  
  const checkProgress = async (zipId: string) => {
    try {
      const response = await fetch(`/api/zip-progress/${zipId}`);
      const data = await response.json();
      setProgress(data);
      return data;
    } catch (error) {
      setProgress({ status: 'error', message: 'Error checking progress' });
    }
  };
  
  return { progress, checkProgress };
}
```

## Deployment Steps

1. **Add these files to your frontend**
2. **Update your environment variables**:
   ```env
   NEXT_PUBLIC_BACKEND_URL=https://invoice-backend-yuhrx5x2ra-uc.a.run.app
   ```
3. **Test with a ZIP-generating query**:
   - "Dame las 10 facturas más recientes"
   - "Facturas de diciembre 2023"

## Backend Improvements Already Deployed

✅ **Increased Resources**: 4GB RAM, 4 CPU cores
✅ **Reduced Concurrency**: 5 instead of 10 (more resources per request)
✅ **Extended Timeout**: 1 hour Cloud Run timeout
✅ **Better Configuration**: Optimized ZIP creation parameters

The new backend deployment (`v20250909-033601`) should handle ZIP creation much faster with the increased resources.

## Testing

Test the improvement with:
```
"Dame las 10 facturas más recientes"
```

Expected behavior:
- Frontend shows ZIP creation warning
- Extended timeout allows completion
- ZIP is created and returned successfully

## Monitoring

Check logs:
```bash
gcloud run services logs tail invoice-backend --region=us-central1
```

Current revision: `invoice-backend-r20250909-033908`