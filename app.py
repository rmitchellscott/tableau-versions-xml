import subprocess
import sys

def handler(event, context):
    subprocess.call("./generateXML.sh")