#!/usr/bin/env python3

import os
import time
import logging
import subprocess
import json
from datetime import datetime
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class NetworkMonitor:
    def __init__(self):
        self.influx_url = os.getenv('INFLUXDB_URL', 'http://influxdb:8086')
        self.influx_token = os.getenv('INFLUXDB_TOKEN')
        self.influx_org = os.getenv('INFLUXDB_ORG', 'NetworkMonitoring')
        self.influx_bucket = os.getenv('INFLUXDB_BUCKET', 'network_metrics')
        
        self.target1 = os.getenv('TARGET1', '8.8.8.8')
        self.target1_name = os.getenv('TARGET1_NAME', 'Google DNS')
        self.target2 = os.getenv('TARGET2', '1.1.1.1')
        self.target2_name = os.getenv('TARGET2_NAME', 'Cloudflare DNS')
        
        self.collection_interval = int(os.getenv('COLLECTION_INTERVAL', '30'))
        
        # Initialize InfluxDB client
        self.client = InfluxDBClient(
            url=self.influx_url,
            token=self.influx_token,
            org=self.influx_org
        )
        self.write_api = self.client.write_api(write_options=SYNCHRONOUS)
        
        logger.info(f"Monitoring targets: {self.target1_name} ({self.target1}), {self.target2_name} ({self.target2})")
        logger.info(f"Collection interval: {self.collection_interval} seconds")

    def ping_target(self, target, target_name):
        """Perform ping test and return metrics"""
        try:
            # Perform ping test (10 packets)
            result = subprocess.run(
                ['ping', '-c', '10', '-i', '0.2', target],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode != 0:
                logger.warning(f"Ping to {target_name} ({target}) failed")
                return {
                    'target': target,
                    'target_name': target_name,
                    'success': False,
                    'packet_loss': 100.0,
                    'avg_rtt': None,
                    'min_rtt': None,
                    'max_rtt': None,
                    'stddev_rtt': None
                }

            # Parse ping output
            output_lines = result.stdout.split('\n')
            
            # Extract packet loss
            packet_loss = 0.0
            for line in output_lines:
                if '% packet loss' in line:
                    packet_loss = float(line.split('%')[0].split()[-1])
                    break
            
            # Extract RTT statistics
            rtt_stats = None
            for line in output_lines:
                if 'min/avg/max/stddev' in line or 'min/avg/max/mdev' in line:
                    rtt_part = line.split('=')[-1].strip()
                    rtt_values = rtt_part.split('/')
                    if len(rtt_values) >= 4:
                        rtt_stats = {
                            'min': float(rtt_values[0]),
                            'avg': float(rtt_values[1]),
                            'max': float(rtt_values[2]),
                            'stddev': float(rtt_values[3].split()[0])
                        }
                    break
            
            if not rtt_stats:
                # Fallback parsing for different ping output formats
                rtt_stats = {'min': 0, 'avg': 0, 'max': 0, 'stddev': 0}
            
            return {
                'target': target,
                'target_name': target_name,
                'success': True,
                'packet_loss': packet_loss,
                'avg_rtt': rtt_stats['avg'],
                'min_rtt': rtt_stats['min'],
                'max_rtt': rtt_stats['max'],
                'stddev_rtt': rtt_stats['stddev']
            }
            
        except subprocess.TimeoutExpired:
            logger.error(f"Ping to {target_name} ({target}) timed out")
            return {
                'target': target,
                'target_name': target_name,
                'success': False,
                'packet_loss': 100.0,
                'avg_rtt': None,
                'min_rtt': None,
                'max_rtt': None,
                'stddev_rtt': None
            }
        except Exception as e:
            logger.error(f"Error pinging {target_name} ({target}): {e}")
            return {
                'target': target,
                'target_name': target_name,
                'success': False,
                'packet_loss': 100.0,
                'avg_rtt': None,
                'min_rtt': None,
                'max_rtt': None,
                'stddev_rtt': None
            }

    def perform_speed_test(self):
        """Perform a realistic speed test using multiple methods"""
        try:
            download_speed_mbps = 0
            upload_speed_mbps = 0
            
            # Method 1: Download test using a reliable speed test file
            logger.info("Starting download speed test...")
            try:
                # Use a 10MB test file from a reliable CDN
                start_time = time.time()
                result = subprocess.run([
                    'curl', '-s', '-o', '/dev/null', '-w', '%{speed_download}',
                    '--max-time', '30',
                    'http://speedtest.tele2.net/10MB.zip'
                ], capture_output=True, text=True, timeout=35)
                
                if result.returncode == 0 and result.stdout.strip():
                    download_speed_bps = float(result.stdout.strip())
                    download_speed_mbps = (download_speed_bps * 8) / (1024 * 1024)  # Convert to Mbps
                    logger.info(f"Download speed: {download_speed_mbps:.2f} Mbps")
                else:
                    logger.warning("Download speed test failed, trying alternative method")
                    # Alternative: smaller file test
                    result = subprocess.run([
                        'curl', '-s', '-o', '/dev/null', '-w', '%{speed_download}',
                        '--max-time', '15',
                        'http://speedtest.tele2.net/1MB.zip'
                    ], capture_output=True, text=True, timeout=20)
                    
                    if result.returncode == 0 and result.stdout.strip():
                        download_speed_bps = float(result.stdout.strip())
                        download_speed_mbps = (download_speed_bps * 8) / (1024 * 1024)
                        logger.info(f"Download speed (alternative): {download_speed_mbps:.2f} Mbps")
                        
            except Exception as e:
                logger.error(f"Download speed test error: {e}")
                download_speed_mbps = 0
            
            # Method 2: Upload test using httpbin or similar service
            logger.info("Starting upload speed test...")
            try:
                # Create a temporary file for upload testing
                test_data = b'0' * (1024 * 1024)  # 1MB of data
                
                start_time = time.time()
                result = subprocess.run([
                    'curl', '-s', '-o', '/dev/null', '-w', '%{speed_upload}',
                    '--max-time', '20',
                    '-X', 'POST',
                    '--data-binary', '@-',
                    'https://httpbin.org/post'
                ], input=test_data, capture_output=True, timeout=25)
                
                if result.returncode == 0 and result.stdout.strip():
                    upload_speed_bps = float(result.stdout.strip())
                    upload_speed_mbps = (upload_speed_bps * 8) / (1024 * 1024)
                    logger.info(f"Upload speed: {upload_speed_mbps:.2f} Mbps")
                else:
                    logger.warning("Upload speed test failed, using alternative")
                    # Simplified upload test
                    upload_speed_mbps = download_speed_mbps * 0.1  # Estimate 10% of download
                    
            except Exception as e:
                logger.error(f"Upload speed test error: {e}")
                upload_speed_mbps = download_speed_mbps * 0.1 if download_speed_mbps > 0 else 0
            
            # Ensure reasonable values and convert to integers for InfluxDB consistency
            download_speed_mbps = max(0, min(1000, download_speed_mbps))  # Cap at 1Gbps
            upload_speed_mbps = max(0, min(1000, upload_speed_mbps))
            
            return {
                'download_speed_mbps': int(round(download_speed_mbps)),  # Convert to integer
                'upload_speed_mbps': int(round(upload_speed_mbps))       # Convert to integer
            }
            
        except Exception as e:
            logger.error(f"Speed test failed: {e}")
            return {
                'download_speed_mbps': 0,
                'upload_speed_mbps': 0
            }

    def write_metrics(self, metrics):
        """Write metrics to InfluxDB"""
        try:
            points = []
            timestamp = datetime.utcnow()
            
            # Write ping metrics for each target
            for target_metrics in metrics['ping_results']:
                point = Point("network_performance") \
                    .tag("target", target_metrics['target']) \
                    .tag("target_name", target_metrics['target_name']) \
                    .field("success", target_metrics['success']) \
                    .field("packet_loss", target_metrics['packet_loss']) \
                    .time(timestamp)
                
                if target_metrics['avg_rtt'] is not None:
                    point = point.field("avg_rtt", target_metrics['avg_rtt']) \
                               .field("min_rtt", target_metrics['min_rtt']) \
                               .field("max_rtt", target_metrics['max_rtt']) \
                               .field("stddev_rtt", target_metrics['stddev_rtt'])
                
                points.append(point)
            
            # Write speed test metrics - ensure integers for consistency
            speed_point = Point("network_speed") \
                .field("download_speed_mbps", int(metrics['speed_test']['download_speed_mbps'])) \
                .field("upload_speed_mbps", int(metrics['speed_test']['upload_speed_mbps'])) \
                .time(timestamp)
            points.append(speed_point)
            
            # Write all points
            self.write_api.write(
                bucket=self.influx_bucket,
                org=self.influx_org,
                record=points
            )
            
            logger.info("Metrics written to InfluxDB successfully")
            
        except Exception as e:
            logger.error(f"Failed to write metrics to InfluxDB: {e}")

    def collect_metrics(self):
        """Collect all network metrics"""
        logger.info("Starting metrics collection...")
        
        # Perform ping tests
        ping_results = [
            self.ping_target(self.target1, self.target1_name),
            self.ping_target(self.target2, self.target2_name)
        ]
        
        # Always perform speed test for manual calls
        logger.info("Running speed test...")
        speed_test = self.perform_speed_test()
        
        metrics = {
            'ping_results': ping_results,
            'speed_test': speed_test,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Log summary
        for result in ping_results:
            if result['success']:
                logger.info(f"{result['target_name']}: {result['avg_rtt']:.1f}ms RTT, {result['packet_loss']:.1f}% loss")
            else:
                logger.warning(f"{result['target_name']}: FAILED")
        
        if speed_test['download_speed_mbps'] > 0:
            logger.info(f"Speed: {speed_test['download_speed_mbps']} Mbps down, {speed_test['upload_speed_mbps']} Mbps up")
        
        return metrics

    def collect_metrics_scheduled(self):
        """Collect metrics for scheduled runs (with speed test frequency control)"""
        logger.info("Starting scheduled metrics collection...")
        
        # Perform ping tests
        ping_results = [
            self.ping_target(self.target1, self.target1_name),
            self.ping_target(self.target2, self.target2_name)
        ]
        
        # Perform speed test every 5 minutes (when minute is divisible by 5)
        speed_test = {'download_speed_mbps': 0, 'upload_speed_mbps': 0}
        
        current_minute = datetime.now().minute
        if current_minute % 5 == 0:  # Run speed test every 5 minutes
            logger.info("Running scheduled speed test...")
            speed_test = self.perform_speed_test()
        else:
            logger.info("Skipping speed test this cycle")
        
        metrics = {
            'ping_results': ping_results,
            'speed_test': speed_test,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Log summary
        for result in ping_results:
            if result['success']:
                logger.info(f"{result['target_name']}: {result['avg_rtt']:.1f}ms RTT, {result['packet_loss']:.1f}% loss")
            else:
                logger.warning(f"{result['target_name']}: FAILED")
        
        if speed_test['download_speed_mbps'] > 0:
            logger.info(f"Speed: {speed_test['download_speed_mbps']} Mbps down, {speed_test['upload_speed_mbps']} Mbps up")
        
        return metrics

    def run(self):
        """Main monitoring loop"""
        logger.info("Starting network monitoring...")
        
        while True:
            try:
                # Collect metrics (scheduled version with speed test frequency control)
                metrics = self.collect_metrics_scheduled()
                
                # Write to InfluxDB
                self.write_metrics(metrics)
                
                # Wait for next collection
                time.sleep(self.collection_interval)
                
            except KeyboardInterrupt:
                logger.info("Monitoring stopped by user")
                break
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                time.sleep(10)  # Wait before retrying

if __name__ == "__main__":
    monitor = NetworkMonitor()
    monitor.run()