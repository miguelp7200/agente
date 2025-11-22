#!/usr/bin/env python3
"""Analyze URL bug - 1086 repetitions in signature"""
import json

# Load JSON
with open(
    "test_results/url_validation_20251121_150514.json", "r", encoding="utf-8"
) as f:
    data = json.load(f)

# Good URL (first one)
good = data[0]
print("=" * 80)
print("GOOD URL (Index 1)")
print("=" * 80)
print(f"FileName: {good['FileName']}")
print(f"Length: {len(good['Url'])} chars")
good_sig = good["Url"].split("X-Goog-Signature=")[1]
print(f"Signature length: {len(good_sig)} chars")
print(f"First 200 chars of signature: {good_sig[:200]}")
print()

# Bad URL (index 8)
bad = [x for x in data if x["Index"] == 8][0]
print("=" * 80)
print("BAD URL (Index 8)")
print("=" * 80)
print(f"FileName: {bad['FileName']}")
print(f"Length: {len(bad['Url'])} chars")
bad_sig = bad["Url"].split("X-Goog-Signature=")[1]
print(f"Signature length: {len(bad_sig)} chars")
print(f"First 200 chars of signature: {bad_sig[:200]}")
print(f"Last 200 chars of signature: {bad_sig[-200:]}")
print()

# Find the repeating pattern
print("=" * 80)
print("PATTERN ANALYSIS")
print("=" * 80)

# Take a chunk from the end (where it's clearly repeating)
chunk = "4413de83acab97142afc1b34aadc153b736b9c244a0da9cc5acea591bc93befb8254"
count = bad_sig.count(chunk)
print(f"Pattern: {chunk}")
print(f"Pattern length: {len(chunk)} chars")
print(f"Occurrences: {count}")
print(f"Total from pattern: {len(chunk) * count} chars")
print(f"Actual signature: {len(bad_sig)} chars")
print(f"Difference: {len(bad_sig) - (len(chunk) * count)} chars")
print()

# Where does the repetition start?
first_occurrence = bad_sig.find(chunk)
print(f"First occurrence at position: {first_occurrence}")
print(f"Before repetition: {bad_sig[:first_occurrence]}")
print(f"Before repetition length: {len(bad_sig[:first_occurrence])} chars")
print()

# Analyze URL structure
print("=" * 80)
print("URL STRUCTURE ANALYSIS")
print("=" * 80)
parts = bad["Url"].split("?")
print(f"Base URL: {parts[0]}")
if len(parts) > 1:
    params = parts[1].split("&")
    print(f"Number of parameters: {len(params)}")
    for i, param in enumerate(params):
        print(f"  [{i+1}] {param[:100]}" + ("..." if len(param) > 100 else ""))

print()

# Check if signature parameter appears multiple times
print("=" * 80)
print("SIGNATURE PARAMETER CHECK")
print("=" * 80)
signature_count = bad["Url"].count("X-Goog-Signature=")
print(f"X-Goog-Signature appears: {signature_count} times")
if signature_count > 1:
    print("⚠️ MULTIPLE SIGNATURE PARAMETERS - This is the bug!")
