#!/usr/bin/env python3
"""
Example script to upload and process JSONL files via LightRAG API.

This script demonstrates:
1. Uploading a JSONL file to LightRAG
2. Querying for information from the uploaded data
3. Handling track IDs to monitor processing status

Usage:
    python examples/upload_jsonl_example.py

Requirements:
    - LightRAG server running on localhost:9621
    - requests library: pip install requests
"""

import asyncio
import json
import time
from pathlib import Path

import requests

# Configuration
API_BASE_URL = "http://localhost:9621"
JSONL_FILE = "examples/sample_data.jsonl"
API_KEY = None  # Set to your API key if authentication is enabled

# Session with default headers
session = requests.Session()
if API_KEY:
    session.headers.update({"X-API-Key": API_KEY})


def upload_jsonl_file(file_path: str) -> dict:
    """Upload a JSONL file to LightRAG.
    
    Args:
        file_path: Path to the JSONL file
        
    Returns:
        Response containing track_id and upload status
    """
    print(f"\n📤 Uploading JSONL file: {file_path}")
    
    if not Path(file_path).exists():
        print(f"❌ File not found: {file_path}")
        return None
    
    with open(file_path, "rb") as f:
        files = {"file": (Path(file_path).name, f, "application/x-jsonl")}
        response = session.post(f"{API_BASE_URL}/documents/upload", files=files)
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Upload successful!")
        print(f"   Track ID: {data.get('track_id')}")
        print(f"   Status: {data.get('status')}")
        print(f"   Message: {data.get('message')}")
        return data
    else:
        print(f"❌ Upload failed!")
        print(f"   Status: {response.status_code}")
        print(f"   Error: {response.text}")
        return None


def check_processing_status(track_id: str) -> dict:
    """Check the processing status of an uploaded document.
    
    Args:
        track_id: The track ID from the upload response
        
    Returns:
        Processing status information
    """
    response = session.get(f"{API_BASE_URL}/documents/track_status/{track_id}")
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Failed to get status: {response.status_code}")
        return None


def wait_for_processing(track_id: str, max_wait: int = 300) -> bool:
    """Wait for the document to be processed.
    
    Args:
        track_id: The track ID to monitor
        max_wait: Maximum seconds to wait (default 5 minutes)
        
    Returns:
        True if processing completed successfully, False otherwise
    """
    print(f"\n⏳ Waiting for processing to complete...")
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        status_data = check_processing_status(track_id)
        
        if not status_data:
            time.sleep(2)
            continue
        
        # Check overall status
        if "status" in status_data:
            status = status_data["status"]
            print(f"   Status: {status}")
            
            if status == "PROCESSED":
                print(f"✅ Processing completed successfully!")
                return True
            elif status == "FAILED":
                print(f"❌ Processing failed!")
                if "error_msg" in status_data:
                    print(f"   Error: {status_data['error_msg']}")
                return False
        
        time.sleep(2)
    
    print(f"⚠️  Timeout reached. Processing may still be ongoing.")
    return False


def query_documents(query: str) -> dict:
    """Query the processed documents.
    
    Args:
        query: The query string
        
    Returns:
        Query results from LightRAG
    """
    print(f"\n🔍 Querying: {query}")
    
    payload = {
        "query": query,
        "param": {
            "mode": "hybrid",
            "top_k": 5,
        }
    }
    
    response = session.post(
        f"{API_BASE_URL}/query",
        json=payload,
        headers={"Content-Type": "application/json"}
    )
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ Query successful!")
        print(f"\nResponse:")
        print(result.get("response", ""))
        
        if "references" in result and result["references"]:
            print(f"\nReferences:")
            for i, ref in enumerate(result["references"], 1):
                print(f"  {i}. {ref.get('file_path', 'unknown')}")
                if ref.get("content"):
                    for chunk in ref["content"][:2]:  # Show first 2 chunks
                        print(f"     - {chunk[:100]}...")
        
        return result
    else:
        print(f"❌ Query failed!")
        print(f"   Status: {response.status_code}")
        print(f"   Error: {response.text}")
        return None


def get_document_status() -> dict:
    """Get overall document status summary."""
    print(f"\n📊 Fetching document statistics...")
    
    response = session.get(f"{API_BASE_URL}/documents/status_counts")
    
    if response.status_code == 200:
        data = response.json()
        print(f"✅ Document Status Summary:")
        for status, count in data.items():
            print(f"   {status}: {count}")
        return data
    else:
        print(f"❌ Failed to get status: {response.status_code}")
        return None


def main():
    """Main example workflow."""
    print("=" * 60)
    print("🚀 LightRAG JSONL Upload Example")
    print("=" * 60)
    
    # Check if API is available
    try:
        response = session.get(f"{API_BASE_URL}/health")
        if response.status_code != 200:
            print(f"❌ LightRAG API is not responding correctly")
            print(f"   Please make sure the service is running on {API_BASE_URL}")
            return
    except Exception as e:
        print(f"❌ Cannot connect to LightRAG API")
        print(f"   Error: {e}")
        print(f"   Please make sure the service is running on {API_BASE_URL}")
        return
    
    print(f"✅ Connected to LightRAG API: {API_BASE_URL}\n")
    
    # Upload JSONL file
    upload_response = upload_jsonl_file(JSONL_FILE)
    if not upload_response:
        return
    
    track_id = upload_response.get("track_id")
    
    # Wait for processing
    if wait_for_processing(track_id):
        # Get document status
        get_document_status()
        
        # Example queries
        queries = [
            "What is machine learning?",
            "Explain deep learning and neural networks",
            "What are different types of machine learning?",
        ]
        
        for query in queries:
            query_documents(query)
            print()
    else:
        print("❌ Document processing failed, skipping query examples")
    
    print("\n" + "=" * 60)
    print("✅ Example completed!")
    print("=" * 60)


if __name__ == "__main__":
    main()
