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
from socketserver import ThreadingMixIn

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Handle requests in a separate thread."""
    daemon_threads = True
    allow_reuse_address = True
    
    def __init__(self, server_address, RequestHandlerClass):
        super().__init__(server_address, RequestHandlerClass)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

class ManualTestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests for health check"""
        try:
            if self.path == '/health':
                logger.info("Health check request received")
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Connection', 'keep-alive')
                self.end_headers()
                
                response = {
                    'status': 'healthy', 
                    'timestamp': time.time(),
                    'server': 'manual-test-server',
                    'version': '1.0',
                    'endpoints': {
                        'health': '/health',
                        'manual_test': '/manual-test'
                    }
                }
                
                response_data = json.dumps(response, indent=2).encode('utf-8')
                self.wfile.write(response_data)
                logger.info("Health check response sent successfully")
                
            else:
                self.send_error(404, "Not Found")
                
        except Exception as e:
            logger.error(f"Error in GET request: {e}")
            try:
                self.send_error(500, f"Internal Server Error: {e}")
            except:
                pass
    
    def do_POST(self):
        """Handle POST requests for manual tests"""
        try:
            parsed_path = urlparse(self.path)
            
            if parsed_path.path == '/manual-test':
                logger.info("Manual test POST request received")
                self.handle_manual_test()
            else:
                self.send_error(404, "Not Found")
                
        except Exception as e:
            logger.error(f"Error in POST request: {e}")
            try:
                self.send_error(500, f"Internal Server Error: {e}")
            except:
                pass
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        try:
            logger.info("CORS preflight request received")
            
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
            self.send_header('Access-Control-Max-Age', '86400')
            self.send_header('Connection', 'keep-alive')
            self.end_headers()
            
            logger.info("CORS preflight response sent")
            
        except Exception as e:
            logger.error(f"Error in OPTIONS request: {e}")
    
    def handle_manual_test(self):
        """Execute manual network test"""
        try:
            logger.info("Processing manual test request...")
            
            # Read request body if present
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > 0:
                post_data = self.rfile.read(content_length)
                logger.info(f"Received POST data: {post_data}")
            
            # Send immediate response
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            self.send_header('Connection', 'keep-alive')
            self.end_headers()
            
            response = {
                'status': 'success',
                'message': 'Manual test started successfully',
                'timestamp': time.time(),
                'note': 'Results will be available in InfluxDB/Grafana in ~30 seconds'
            }
            
            response_data = json.dumps(response, indent=2).encode('utf-8')
            self.wfile.write(response_data)
            logger.info("Manual test response sent, starting background test...")
            
            # Start test in background thread
            test_thread = threading.Thread(target=self.run_test_async)
            test_thread.daemon = True
            test_thread.start()
            
        except Exception as e:
            logger.error(f"Error handling manual test: {e}")
            try:
                self.send_error(500, f"Internal Server Error: {e}")
            except:
                pass
    
    def run_test_async(self):
        """Run the actual test in background"""
        try:
            logger.info("Starting background manual network test...")
            
            # Execute the collector directly
            result = subprocess.run([
                'python3', '-c', '''
import sys
sys.path.append('/app')
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
            timeout=120,
            env=dict(os.environ)
            )
            
            if result.returncode == 0:
                logger.info("Manual test completed successfully")
                logger.info(f"Test output: {result.stdout}")
            else:
                logger.error(f"Manual test failed with return code {result.returncode}")
                logger.error(f"Error output: {result.stderr}")
                logger.error(f"Stdout: {result.stdout}")
                
        except subprocess.TimeoutExpired:
            logger.error("Manual test timed out after 120 seconds")
        except Exception as e:
            logger.error(f"Error running manual test: {e}")
            import traceback
            traceback.print_exc()
    
    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(f"{self.address_string()} - {format % args}")

def test_port_availability():
    """Test if port 8080 is available"""
    try:
        test_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        test_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        test_socket.bind(('0.0.0.0', 8080))
        test_socket.close()
        logger.info("Port 8080 is available")
        return True
    except OSError as e:
        logger.error(f"Port 8080 is not available: {e}")
        return False

def run_server():
    """Run the manual test server"""
    logger.info("Initializing Manual Test Server...")
    
    # Test port availability
    if not test_port_availability():
        logger.error("Cannot start server - port not available")
        return
    
    server_address = ('0.0.0.0', 8080)
    
    try:
        httpd = ThreadedHTTPServer(server_address, ManualTestHandler)
        
        logger.info("Manual Test Server starting on 0.0.0.0:8080...")
        logger.info("Server configuration:")
        logger.info(f"  - Address: {server_address}")
        logger.info(f"  - Threading: Enabled")
        logger.info(f"  - Reuse Address: Enabled")
        logger.info("")
        logger.info("Available endpoints:")
        logger.info("  GET  /health      - Health check")
        logger.info("  POST /manual-test - Execute manual network test")
        logger.info("")
        logger.info("Server is ready to accept connections")
        
        # Start serving
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