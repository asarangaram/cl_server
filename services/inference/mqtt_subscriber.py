"""Simple MQTT subscriber to test if messages are being published."""

import paho.mqtt.client as mqtt
import json

def on_connect(client, userdata, flags, rc, properties=None):
    print(f"Connected with result code {rc}")
    client.subscribe("inference/events")
    print("Subscribed to inference/events")

def on_message(client, userdata, msg):
    print(f"\n📨 Received message on {msg.topic}:")
    try:
        payload = json.loads(msg.payload.decode())
        print(json.dumps(payload, indent=2))
    except:
        print(msg.payload.decode())

client = mqtt.Client(protocol=mqtt.MQTTv5)
client.on_connect = on_connect
client.on_message = on_message

print("Connecting to MQTT broker...")
client.connect("localhost", 1883, 60)

print("Listening for messages... (Press Ctrl+C to stop)")
client.loop_forever()
