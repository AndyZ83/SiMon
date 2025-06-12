#!/usr/bin/env python3

import os
import json
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import subprocess
import threading
import time

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ManualTestHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        """Handle POST requests for manual tests"""
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/manual-test':
            self.handle_manual_test()
        else:
            self.send_error(404, "Not Found")
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def handle_manual_test(self):
        """Execute manual network test"""
        try:
            # Set CORS headers
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            # Start test in background thread
            test_thread = threading.Thread(target=self.run_test_async)
            test_thread.daemon = True
            test_thread.start()
            
            # Return immediate response
            response = {
                'status': 'success',
                'message': 'Manual test started',
                'timestamp': time.time()
            }
            
            self.wfile.write(json.dumps(response).encode())
            logger.info("Manual test request received and started")
            
        except Exception as e:
            logger.error(f"Error handling manual test: {e}")
            self.send_error(500, f"Internal Server Error: {e}")
    
    def run_test_async(self):
        """Run the actual test in background"""
        try:
            logger.info("Starting manual network test...")
            
            # Execute the collector directly
            result = subprocess.run([
                'python3', '-c', '''
from collector import NetworkMonitor
import json

try:
    monitor = NetworkMonitor()
    print("Starting manual test...")
    
    # Collect all metrics including speed test
    metrics = monitor.collect_metrics()
    
    # Force speed test if not already done
    if metrics["speed_test"]["download_speed_mbps"] == 0:
        print("Running forced speed test...")
        speed_test = monitor.perform_speed_test()
        metrics["speed_test"] = speed_test
    
    # Write to InfluxDB
    monitor.write_metrics(metrics)
    
    print("Manual test completed successfully!")
    print(f"Results: {json.dumps(metrics, indent=2, default=str)}")
    
except Exception as e:
    print(f"Manual test failed: {e}")
    import traceback
    traceback.print_exc()
'''
            ], 
            cwd='/app',
            capture_output=True, 
            text=True, 
            timeout=120
            )
            
            if result.returncode == 0:
                logger.info("Manual test completed successfully")
                logger.info(f"Test output: {result.stdout}")
            else:
                logger.error(f"Manual test failed with return code {result.returncode}")
                logger.error(f"Error output: {result.stderr}")
                
        except subprocess.TimeoutExpired:
            logger.error("Manual test timed out after 120 seconds")
        except Exception as e:
            logger.error(f"Error running manual test: {e}")
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(f"{self.address_string()} - {format % args}")

def run_server():
    """Run the manual test server"""
    server_address = ('0.0.0.0', 8080)
    httpd = HTTPServer(server_address, ManualTestHandler)
    
    logger.info("Manual Test Server starting on port 8080...")
    logger.info("Endpoints:")
    logger.info("  POST /manual-test - Execute manual network test")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
    finally:
        httpd.server_close()

if __name__ == "__main__":
    run_server()