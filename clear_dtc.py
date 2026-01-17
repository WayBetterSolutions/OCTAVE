#!/usr/bin/env python3
"""Clear DTCs script"""

import obd

obd.logger.setLevel(obd.logging.DEBUG)

connection = obd.OBD("/dev/rfcomm0")

if connection.is_connected():
    print("Clearing DTCs...")
    response = connection.query(obd.commands.CLEAR_DTC)
    print(f"Response: {response}")
    print("DTCs cleared (if supported)")
else:
    print("Failed to connect")

connection.close()
