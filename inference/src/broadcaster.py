"""MQTT Broadcaster for inference events."""

import json
import logging
import time
from typing import Any, Dict, Optional

import paho.mqtt.client as mqtt

from .config import BROADCAST_TYPE, MQTT_BROKER, MQTT_PORT, MQTT_TOPIC

logger = logging.getLogger(__name__)


class Broadcaster:
    """Handles broadcasting of events via MQTT."""

    def __init__(self):
        """Initialize broadcaster."""
        self.enabled = BROADCAST_TYPE == "mqtt"
        self.client: Optional[mqtt.Client] = None
        
        logger.info(f"Broadcaster initialized (enabled={self.enabled}, type={BROADCAST_TYPE})")
        
        if self.enabled:
            self._setup_mqtt()

    def _setup_mqtt(self):
        """Setup MQTT client."""
        try:
            # Use protocol version 5 if available, else default (3.1.1)
            self.client = mqtt.Client(protocol=mqtt.MQTTv5)
            self.client.on_connect = self._on_connect
            self.client.on_disconnect = self._on_disconnect
            
            logger.info(f"Connecting to MQTT broker at {MQTT_BROKER}:{MQTT_PORT}...")
            self.client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.client.loop_start()  # Start background loop
            
        except Exception as e:
            logger.error(f"Failed to setup MQTT client: {e}")
            self.enabled = False

    def _on_connect(self, client, userdata, flags, rc, properties=None):
        """Callback for connection established."""
        if rc == 0:
            logger.info("✅ Connected to MQTT broker")
        else:
            logger.error(f"❌ Failed to connect to MQTT broker with code {rc}")

    def _on_disconnect(self, client, userdata, rc, properties=None):
        """Callback for disconnection."""
        if rc != 0:
            logger.warning("⚠️ Unexpected disconnection from MQTT broker")

    def publish(self, event_type: str, payload: Dict[str, Any]):
        """
        Publish an event.

        Args:
            event_type: Type of event (e.g., 'job_completed')
            payload: Event data
        """
        if not self.enabled:
            logger.debug(f"Broadcaster disabled, skipping publish of {event_type}")
            return
            
        if not self.client:
            logger.warning(f"MQTT client not initialized, cannot publish {event_type}")
            return

        try:
            message = {
                "event": event_type,
                "data": payload,
                "timestamp": int(time.time() * 1000)
            }
            
            json_payload = json.dumps(message)
            logger.info(f"Publishing MQTT event: {event_type} to topic {MQTT_TOPIC}")
            info = self.client.publish(MQTT_TOPIC, json_payload)
            
            if info.rc != mqtt.MQTT_ERR_SUCCESS:
                logger.error(f"Failed to publish message: {mqtt.error_string(info.rc)}")
            else:
                logger.info(f"✅ Published {event_type} event successfully")
                
        except Exception as e:
            logger.error(f"Error publishing message: {e}")

    def close(self):
        """Close connection."""
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()


# Global instance
_broadcaster = None

def get_broadcaster() -> Broadcaster:
    """Get or create global broadcaster instance."""
    global _broadcaster
    if _broadcaster is None:
        _broadcaster = Broadcaster()
    return _broadcaster
