import os
import time
import datetime
import json
import random
import paho.mqtt.client as mqtt
import serial

BROKER_HOST = os.getenv("BROKER_HOST")
if not BROKER_HOST:
    BROKER_HOST = "localhost"

BROKER_PORT = os.getenv("BROKER_PORT")
if BROKER_PORT:
    BROKER_PORT = int(BROKER_PORT)
else:
    BROKER_PORT = 1883

TOPIC_1 = "rpi/sensor1"
TOPIC_2 = "rpi/sensor2"
MQTT_ID = "rpi"


def on_log(client, userdata, level, buf):
    """Create log messages on mqtt events"""
    print("log:", buf)

def main():
    client = mqtt.Client(client_id=MQTT_ID)
    client.on_log = on_log
    client.connect(BROKER_HOST, port=BROKER_PORT)

    client.loop_start()

    ser = serial.Serial('/dev/ttyACM0', 9600, timeout=1)
    ser.flush()
    ser1 = serial.Serial('/dev/ttyACM1', 9600, timeout=1)
    ser1.flush()

    while True:
        if ser.in_waiting > 0:
            line = ser.readline().decode('utf-8').rstrip().split()
            d={}
            d["timeStamp"] = '{:%Y-%m-%d %H:%M:%S}'.format(datetime.datetime.now())
            d["deviceID"] = line[0]
            d["humidity"] = float(line[1])
            d["tempeture"] = float(line[2])
            d["heat_index"] = float(line[3])
            payload = json.dumps(d, ensure_ascii=False)
            print (payload)
            client.publish(TOPIC_1,payload)
            time.sleep(2)
        if ser1.in_waiting > 0:
            line1 = ser1.readline().decode('utf-8').rstrip().split()
            d={}
            d["timeStamp"] = '{:%Y-%m-%d %H:%M:%S}'.format(datetime.datetime.now())
            d["deviceID"] = line1[0]
            d["humidity"] = float(line1[1])
            d["tempeture"] = float(line1[2])
            d["heat_index"] = float(line1[3])
            payload = json.dumps(d, ensure_ascii=False)
            print (payload)
            client.publish(TOPIC_2,payload)
            time.sleep(2)


if __name__ == "__main__":
    main()
