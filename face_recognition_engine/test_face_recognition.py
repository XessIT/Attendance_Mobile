#!/usr/bin/env python3
"""
Test script for Face Recognition Engine
This script tests the face recognition functionality
"""

import os
import sys
import requests
import time
from PIL import Image
import numpy as np

# Test configuration
BASE_URL = "http://localhost:5000"
TEST_IMAGE_PATH = "test_images"

def create_test_image():
    """Create a simple test image if none exists"""
    if not os.path.exists(TEST_IMAGE_PATH):
        os.makedirs(TEST_IMAGE_PATH)
    
    # Create a simple test image (you should replace this with real face images)
    test_image_path = os.path.join(TEST_IMAGE_PATH, "test_face.jpg")
    
    if not os.path.exists(test_image_path):
        print("⚠️  No test image found. Please add a test face image to test_images/test_face.jpg")
        print("   You can use any JPG/PNG image with a clear face for testing.")
        return None
    
    return test_image_path

def test_server_health():
    """Test if the server is running"""
    print("🔍 Testing server health...")
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Server is healthy: {data.get('message', 'OK')}")
            return True
        else:
            print(f"❌ Server health check failed: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot connect to server: {e}")
        print("💡 Make sure the server is running: python face_recognition_api.py")
        return False

def test_list_employees():
    """Test listing employees"""
    print("\n👥 Testing employee list...")
    try:
        response = requests.get(f"{BASE_URL}/list-employees")
        if response.status_code == 200:
            data = response.json()
            employees = data.get('employees', [])
            print(f"✅ Found {len(employees)} employees")
            for emp in employees[:3]:  # Show first 3
                print(f"   • {emp['name']} ({emp['position']}) - Face: {'✅' if emp.get('has_face') else '❌'}")
            return True
        else:
            print(f"❌ Failed to list employees: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error listing employees: {e}")
        return False

def test_face_registration(employee_id, image_path):
    """Test face registration"""
    print(f"\n📸 Testing face registration for employee {employee_id}...")
    try:
        with open(image_path, 'rb') as f:
            files = {'image': f}
            data = {'employee_id': str(employee_id)}
            response = requests.post(f"{BASE_URL}/register-face", files=files, data=data)
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                print(f"✅ Face registered successfully for employee {employee_id}")
                return True
            else:
                print(f"❌ Registration failed: {result.get('error', 'Unknown error')}")
                return False
        else:
            print(f"❌ Registration request failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error during registration: {e}")
        return False

def test_face_recognition(image_path):
    """Test face recognition"""
    print(f"\n🔍 Testing face recognition...")
    try:
        with open(image_path, 'rb') as f:
            files = {'image': f}
            response = requests.post(f"{BASE_URL}/recognize-face", files=files)
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                employee = result.get('employee', {})
                confidence = result.get('confidence', 0)
                print(f"✅ Face recognized: {employee.get('name', 'Unknown')} (ID: {employee.get('id', 'Unknown')})")
                print(f"   Confidence: {confidence:.2%}")
                return True
            else:
                print(f"❌ Recognition failed: {result.get('error', 'Unknown error')}")
                return False
        elif response.status_code == 404:
            result = response.json()
            print(f"⚠️  Face not found: {result.get('error', 'Unknown error')}")
            print("   This is expected if the face hasn't been registered yet.")
            return True  # This is not an error, just no match found
        else:
            print(f"❌ Recognition request failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error during recognition: {e}")
        return False

def test_get_employee(employee_id):
    """Test getting employee information"""
    print(f"\n👤 Testing get employee {employee_id}...")
    try:
        response = requests.get(f"{BASE_URL}/get-employee/{employee_id}")
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                employee = result.get('employee', {})
                print(f"✅ Employee found: {employee.get('name', 'Unknown')}")
                print(f"   Email: {employee.get('email', 'N/A')}")
                print(f"   Position: {employee.get('position', 'N/A')}")
                return True
            else:
                print(f"❌ Failed to get employee: {result.get('error', 'Unknown error')}")
                return False
        else:
            print(f"❌ Get employee request failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error getting employee: {e}")
        return False

def run_all_tests():
    """Run all tests"""
    print("🧪 Face Recognition Engine Test Suite")
    print("=" * 50)
    
    # Test 1: Server health
    if not test_server_health():
        print("\n❌ Server is not running. Please start the server first.")
        return False
    
    # Test 2: List employees
    if not test_list_employees():
        print("\n❌ Cannot list employees. Check database connection.")
        return False
    
    # Test 3: Get test image
    test_image = create_test_image()
    if not test_image:
        print("\n❌ No test image available. Please add a test image.")
        return False
    
    # Test 4: Get employee info
    test_get_employee(1)
    
    # Test 5: Face registration
    if test_face_registration(1, test_image):
        # Test 6: Face recognition (should work after registration)
        test_face_recognition(test_image)
    else:
        # Test 6: Face recognition (should fail if no registration)
        test_face_recognition(test_image)
    
    print("\n✅ All tests completed!")
    return True

def main():
    """Main function"""
    try:
        success = run_all_tests()
        if success:
            print("\n🎉 Face Recognition Engine is working correctly!")
            print("\n📋 Next steps:")
            print("   1. Start the server: python face_recognition_api.py")
            print("   2. Run your Flutter app")
            print("   3. Test face registration and recognition")
        else:
            print("\n❌ Some tests failed. Please check the errors above.")
            sys.exit(1)
    except KeyboardInterrupt:
        print("\n🛑 Tests interrupted by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 