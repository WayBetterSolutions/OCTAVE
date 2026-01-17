#!/usr/bin/env python3
"""Simple DTC reader test script"""

import obd

# Enable debug logging
obd.logger.setLevel(obd.logging.DEBUG)

# Connect explicitly to rfcomm0
connection = obd.OBD("/dev/rfcomm0")

print(f"Connected: {connection.is_connected()}")
print(f"Port: {connection.port_name()}")
print(f"Protocol: {connection.protocol_name()}")

if connection.is_connected():
    # Query DTCs
    response = connection.query(obd.commands.GET_DTC)
    print(f"\nDTC Response: {response}")
    print(f"Value: {response.value}")

    # Also try getting current DTCs
    if obd.commands.GET_CURRENT_DTC in connection.supported_commands:
        current = connection.query(obd.commands.GET_CURRENT_DTC)
        print(f"\nCurrent DTCs: {current.value}")
else:
    print("\nFailed to connect. Check your Bluetooth connection.")
    print("You may need to specify the port manually, e.g.:")
    print("  connection = obd.OBD('/dev/rfcomm0')")
    print("  connection = obd.OBD('/dev/ttyUSB0')")

connection.close()
