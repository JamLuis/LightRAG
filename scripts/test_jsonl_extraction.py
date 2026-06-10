#!/usr/bin/env python3
"""
Quick test script to verify JSONL upload functionality.
Tests if the JSONL extraction function works correctly.
"""

import sys
import json
from pathlib import Path


def _extract_jsonl(file_bytes: bytes) -> str:
    """
    Extract text content from JSONL file.
    JSONL (JSON Lines) format: one JSON object per line.
    Each line is treated as a separate record.
    
    The function attempts to extract content from common field names:
    text, content, message, data, body. If none are found, the entire
    JSON object is serialized as a string.
    """
    try:
        text_content = file_bytes.decode("utf-8")
        lines = text_content.strip().split("\n")
        extracted_texts = []

        for line_num, line in enumerate(lines, 1):
            line = line.strip()
            if not line:  # Skip empty lines
                continue

            try:
                obj = json.loads(line)
                # Convert the JSON object to a formatted string
                # Try common field names for content
                content_field = None
                for field in ["text", "content", "message", "data", "body"]:
                    if field in obj:
                        content_field = field
                        break

                if content_field:
                    # Use the identified content field
                    extracted_texts.append(str(obj[content_field]))
                else:
                    # If no known field found, convert entire object to string
                    extracted_texts.append(json.dumps(obj, ensure_ascii=False))

            except json.JSONDecodeError as e:
                print(f"[Warning] Skipping invalid JSON on line {line_num}: {str(e)}")
                continue

        if not extracted_texts:
            raise ValueError(
                "No valid JSON lines found in JSONL file or all lines are empty"
            )

        # Join all extracted texts with newlines
        return "\n".join(extracted_texts)

    except UnicodeDecodeError as e:
        raise ValueError(f"JSONL file is not UTF-8 encoded: {str(e)}")
    except Exception as e:
        raise ValueError(f"Error processing JSONL file: {str(e)}")


def test_basic_jsonl():
    """Test basic JSONL extraction with common field names."""
    test_data = b'''{"text": "First document with text field"}
{"content": "Second document with content field"}
{"message": "Third document with message field"}
{"data": "Fourth document with data field"}
{"body": "Fifth document with body field"}'''
    
    try:
        result = _extract_jsonl(test_data)
        lines = result.split('\n')
        assert len(lines) == 5, f"Expected 5 lines, got {len(lines)}"
        print("✅ Basic JSONL extraction: PASSED")
        return True
    except Exception as e:
        print(f"❌ Basic JSONL extraction: FAILED - {e}")
        return False


def test_empty_lines():
    """Test JSONL with empty lines."""
    test_data = b'''{"text": "First"}

{"text": "Second"}

{"text": "Third"}'''
    
    try:
        result = _extract_jsonl(test_data)
        lines = result.split('\n')
        assert len(lines) == 3, f"Expected 3 lines, got {len(lines)}"
        print("✅ Empty lines handling: PASSED")
        return True
    except Exception as e:
        print(f"❌ Empty lines handling: FAILED - {e}")
        return False


def test_mixed_fields():
    """Test JSONL with mixed field names."""
    test_data = b'''{"text": "Document 1"}
{"content": "Document 2"}
{"text": "Document 3"}
{"message": "Document 4"}'''
    
    try:
        result = _extract_jsonl(test_data)
        assert "Document 1" in result
        assert "Document 2" in result
        assert "Document 3" in result
        assert "Document 4" in result
        print("✅ Mixed fields handling: PASSED")
        return True
    except Exception as e:
        print(f"❌ Mixed fields handling: FAILED - {e}")
        return False


def test_no_recognized_fields():
    """Test JSONL with objects but no recognized fields."""
    test_data = b'''{"name": "Alice", "age": 30}
{"title": "Test", "date": "2024-01-01"}'''
    
    try:
        result = _extract_jsonl(test_data)
        assert len(result) > 0, "Should extract JSON objects as strings"
        print("✅ Unrecognized fields (serialize as string): PASSED")
        return True
    except Exception as e:
        print(f"❌ Unrecognized fields: FAILED - {e}")
        return False


def test_special_characters():
    """Test JSONL with special characters and unicode."""
    test_data = b'''{"text": "Hello \\u4e16\\u754c"}
{"text": "Emoji test: \\ud83d\\ude00"}
{"text": "Special chars: \\t\\n\\r"}'''
    
    try:
        result = _extract_jsonl(test_data)
        assert len(result) > 0
        print("✅ Special characters/Unicode: PASSED")
        return True
    except Exception as e:
        print(f"❌ Special characters: FAILED - {e}")
        return False


def test_encoding_error():
    """Test invalid UTF-8 encoding."""
    test_data = b'\xff\xfe{"text": "Invalid UTF-8"}'
    
    try:
        result = _extract_jsonl(test_data)
        print(f"❌ Should have raised encoding error")
        return False
    except ValueError as e:
        if "UTF-8" in str(e):
            print("✅ UTF-8 encoding error handling: PASSED")
            return True
        else:
            print(f"❌ Wrong error: {e}")
            return False


def test_empty_file():
    """Test empty JSONL file."""
    test_data = b''
    
    try:
        result = _extract_jsonl(test_data)
        print(f"❌ Should have raised ValueError for empty file")
        return False
    except ValueError as e:
        if "No valid JSON" in str(e) or "empty" in str(e).lower():
            print("✅ Empty file error handling: PASSED")
            return True
        else:
            print(f"❌ Wrong error: {e}")
            return False


def test_only_whitespace():
    """Test file with only whitespace."""
    test_data = b'\n\n  \n  \n'
    
    try:
        result = _extract_jsonl(test_data)
        print(f"❌ Should have raised ValueError for whitespace-only file")
        return False
    except ValueError as e:
        if "No valid JSON" in str(e):
            print("✅ Whitespace-only file error handling: PASSED")
            return True
        else:
            print(f"❌ Wrong error: {e}")
            return False


def main():
    """Run all tests."""
    print("=" * 60)
    print("🧪 JSONL Extraction Function Tests")
    print("=" * 60)
    print()
    
    tests = [
        test_basic_jsonl,
        test_empty_lines,
        test_mixed_fields,
        test_no_recognized_fields,
        test_special_characters,
        test_encoding_error,
        test_empty_file,
        test_only_whitespace,
    ]
    
    results = []
    for test in tests:
        result = test()
        results.append(result)
        print()
    
    # Summary
    passed = sum(results)
    total = len(results)
    
    print("=" * 60)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    print("=" * 60)
    
    if passed == total:
        print("✅ All tests passed!")
        return 0
    else:
        print(f"❌ {total - passed} test(s) failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
