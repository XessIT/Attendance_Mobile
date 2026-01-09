#!/usr/bin/env python3
"""
Face Recognition Server Startup Script
This script starts the face recognition API server
"""

import os
import sys
import subprocess
import time

def check_python_version():
    """Check if Python version is compatible"""
    if sys.version_info < (3, 7):
        print("❌ Error: Python 3.7 or higher is required")
        print(f"Current version: {sys.version}")
        return False
    print(f"✅ Python version: {sys.version}")
    return True

def install_requirements():
    """Install required packages"""
    print("📦 Installing required packages...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✅ Requirements installed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error installing requirements: {e}")
        return False

def check_database_connection():
    """Check database connection"""
    print("🔍 Checking database connection...")
    try:
        import mysql.connector
        from face_recognition_api import get_db_connection
        
        connection = get_db_connection()
        if connection:
            connection.close()
            print("✅ Database connection successful")
            return True
        else:
            print("❌ Database connection failed")
            return False
    except ImportError:
        print("❌ MySQL connector not installed")
        return False
    except Exception as e:
        print(f"❌ Database connection error: {e}")
        return False

def create_upload_folder():
    """Create upload folder if it doesn't exist"""
    upload_folder = "uploads"
    if not os.path.exists(upload_folder):
        os.makedirs(upload_folder)
        print(f"✅ Created upload folder: {upload_folder}")
    else:
        print(f"✅ Upload folder exists: {upload_folder}")

def start_server():
    """Start the face recognition server"""
    print("🚀 Starting Face Recognition API Server...")
    print("=" * 50)
    print("📋 Server Information:")
    print("   • Host: 0.0.0.0")
    print("   • Port: 5000")
    print("   • URL: http://localhost:5000")
    print("   • Health Check: http://localhost:5000/health")
    print("=" * 50)
    
    try:
        from face_recognition_api import app
        app.run(host='0.0.0.0', port=5000, debug=False)
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except Exception as e:
        print(f"❌ Error starting server: {e}")

def main():
    """Main function"""
    print("🎯 Face Recognition Server Setup")
    print("=" * 40)
    
    # Check Python version
    if not check_python_version():
        return
    
    # Install requirements
    if not install_requirements():
        print("💡 Try running: pip install -r requirements.txt manually")
        return
    
    # Check database connection
    if not check_database_connection():
        print("💡 Make sure your MySQL server is running and database is created")
        print("💡 Update database configuration in face_recognition_api.py")
        return
    
    # Create upload folder
    create_upload_folder()
    
    # Start server
    start_server()

if __name__ == "__main__":
    main() 