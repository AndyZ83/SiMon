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
        """Perform a basic speed test using curl"""
        try:
            # Download speed test (download 10MB file)
            start_time = time.time()
            result = subprocess.run([
                'curl', '-s', '-o', '/dev/null', '-w', '%{speed_download}',
                'http://speedtest.tele2.net/10MB.zip'
            ], capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                download_speed_bps = float(result.stdout.strip())
                download_speed_mbps = (download_speed_bps * 8) / (1024 * 1024)  # Convert to Mbps
            else:
                download_speed_mbps = 0
                
            # Upload speed test (upload small file)
            upload_result = subprocess.run([
                'curl', '-s', '-o', '/dev/null', '-w', '%{speed_upload}',
                '-F', 'file=@/dev/zero', '--form-string', 'size=1048576',
                'httpbin.org/post'
            ], capture_output=True, text=True, timeout=30)
            
            if upload_result.returncode == 0:
                upload_speed_bps = float(upload_result.stdout.strip())
                upload_speed_mbps = (upload_speed_bps * 8) / (1024 * 1024)  # Convert to Mbps
            else:
                upload_speed_mbps = 0
                
            return {
                'download_speed_mbps': round(download_speed_mbps, 2),
                'upload_speed_mbps': round(upload_speed_mbps, 2)
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
            
            # Write speed test metrics
            speed_point = Point("network_speed") \
                .field("download_speed_mbps", metrics['speed_test']['download_speed_mbps']) \
                .field("upload_speed_mbps", metrics['speed_test']['upload_speed_mbps']) \
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
        
        # Perform speed test (less frequently)
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
        
        logger.info(f"Speed: {speed_test['download_speed_mbps']:.1f} Mbps down, {speed_test['upload_speed_mbps']:.1f} Mbps up")
        
        return metrics

    def run(self):
        """Main monitoring loop"""
        logger.info("Starting network monitoring...")
        
        while True:
            try:
                # Collect metrics
                metrics = self.collect_metrics()
                
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