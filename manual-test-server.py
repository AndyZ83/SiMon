#!/usr/bin/env python3

import os
import json
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import subprocess
import threading
import time
import socket

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ManualTestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests for health check"""
        if self.path == '/health':
            try:
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Connection', 'close')
                self.end_headers()
                response = {
                    'status': 'healthy', 
                    'timestamp': time.time(),
                    'server': 'manual-test-server',
                    'version': '1.0'
                }
                self.wfile.write(json.dumps(response).encode())
                self.wfile.flush()
                logger.info("Health check request handled successfully")
            except Exception as e:
                logger.error(f"Error in health check: {e}")
        else:
            self.send_error(404, "Not Found")
    
    def do_POST(self):
        """Handle POST requests for manual tests"""
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/manual-test':
            self.handle_manual_test()
        else:
            self.send_error(404, "Not Found")
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        try:
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
            self.send_header('Access-Control-Max-Age', '86400')
            self.send_header('Connection', 'close')
            self.end_headers()
            logger.info("CORS preflight request handled")
        except Exception as e:
            logger.error(f"Error in OPTIONS: {e}")
    
    def handle_manual_test(self):
        """Execute manual network test"""
        try:
            logger.info("Manual test request received")
            
            # Set CORS headers
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            self.send_header('Connection', 'close')
            self.end_headers()
            
            # Start test in background thread
            test_thread = threading.Thread(target=self.run_test_async)
            test_thread.daemon = True
            test_thread.start()
            
            # Return immediate response
            response = {
                'status': 'success',
                'message': 'Manual test started successfully',
                'timestamp': time.time(),
                'note': 'Results will be available in ~30 seconds'
            }
            
            response_json = json.dumps(response)
            self.wfile.write(response_json.encode())
            self.wfile.flush()
            logger.info("Manual test response sent successfully")
            
        except Exception as e:
            logger.error(f"Error handling manual test: {e}")
            try:
                self.send_error(500, f"Internal Server Error: {e}")
            except:
                pass  # Connection might be closed
    
    def run_test_async(self):
        """Run the actual test in background"""
        try:
            logger.info("Starting background manual network test...")
            
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
    print(f"Download: {metrics['speed_test']['download_speed_mbps']} Mbps")
    print(f"Upload: {metrics['speed_test']['upload_speed_mbps']} Mbps")
    
    for ping_result in metrics['ping_results']:
        if ping_result['success']:
            print(f"{ping_result['target_name']}: {ping_result['avg_rtt']}ms RTT, {ping_result['packet_loss']}% loss")
        else:
            print(f"{ping_result['target_name']}: FAILED")
    
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

class ThreadedHTTPServer(HTTPServer):
    """Handle requests in a separate thread."""
    def __init__(self, server_address, RequestHandlerClass):
        super().__init__(server_address, RequestHandlerClass)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.timeout = 30

def run_server():
    """Run the manual test server"""
    server_address = ('0.0.0.0', 8080)
    
    try:
        httpd = ThreadedHTTPServer(server_address, ManualTestHandler)
        logger.info("Manual Test Server starting on 0.0.0.0:8080...")
        logger.info("Endpoints:")
        logger.info("  GET  /health      - Health check")
        logger.info("  POST /manual-test - Execute manual network test")
        
        # Test if port is available
        test_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        test_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            test_socket.bind(('0.0.0.0', 8080))
            test_socket.close()
            logger.info("Port 8080 is available")
        except OSError as e:
            logger.error(f"Port 8080 is not available: {e}")
            test_socket.close()
            return
        
        logger.info("Server is ready to accept connections")
        httpd.serve_forever()
        
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        try:
            httpd.server_close()
            logger.info("Server closed")
        except:
            pass

if __name__ == "__main__":
    run_server()