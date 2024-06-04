import os
import subprocess
import requests
import json
import signal
import time
from dotenv import load_dotenv
from requests.auth import HTTPDigestAuth


# begin init
load_dotenv()

atlas_project_id = os.getenv("ATLAS_PROJECT_ID")
atlas_public_key = os.getenv("ATLAS_PUBLIC_KEY")
atlas_private_key = os.getenv("ATLAS_PRIVATE_KEY")
azure_key_vault_name = os.getenv("AZURE_KEY_VAULT_NAME")
azure_resource_group = os.getenv("AZURE_RESOURCE_GROUP_NAME")
debug = os.getenv("DEBUG", False)

if not all(
    [
        atlas_project_id,
        atlas_public_key,
        atlas_private_key,
        azure_key_vault_name,
        azure_resource_group,
    ]
):
    print(
        "Please set the ATLAS_PROJECT_ID, ATLAS_PUBLIC_KEY, ATLAS_PRIVATE_KEY, AZURE_KEY_VAULT_NAME, and AZURE_RESOURCE_GROUP_NAME environment variables."
    )
    exit(1)

host_url = (
    f"https://cloud.mongodb.com/api/atlas/v2/groups/{atlas_project_id}/ipAddresses"
)
control_url = f"https://cloud.mongodb.com/api/atlas/v2/unauth/controlPlaneIPAddresses"
headers = {"Accept": "application/vnd.atlas.2024-05-30+json"}
# end init


# make HTTP call to admin api to retrieve a list of host IP addresses in the given project
def get_host_ips() -> list[str]:
    try:
        response = requests.get(
            host_url,
            headers=headers,
            auth=HTTPDigestAuth(atlas_public_key, atlas_private_key),
        )
        response.raise_for_status()
        data = response.json()
        clusters = data.get("services", {}).get("clusters", [])

        current_ips = sorted(
            ip for cluster in clusters for ip in cluster.get("outbound", [])
        )
        return current_ips
    except requests.exceptions.RequestException as e:
        print(f"An error occurred: {e}")
    except ValueError as e:
        print(f"Failed to parse JSON response: {e}")
    return []


# make HTTP call to admin api to retrieve a list of control plane IP addresses
def get_control_ips() -> list[str]:
    try:
        response = requests.get(
            control_url,
            headers=headers,
        )
        response.raise_for_status()
        outbound = response.json()["outbound"]
        flattened = []
        for cloud_provider in outbound:
            cp = outbound.get(cloud_provider)
            for region in cp:
                r = cp.get(region)
                for ip in r:
                    flattened.append(ip.split("/")[0])
        return flattened
    except requests.exceptions.RequestException as e:
        print(f"An error occurred: {e}")
    except ValueError as e:
        print(f"Failed to parse JSON response: {e}")
    return []


# make system call to azure client to retrieve a list of IP addresses are current in the AKV Firewall / ACL
def get_azure_acl() -> list[str]:
    try:
        res = subprocess.run(
            [
                "az",
                "keyvault",
                "network-rule",
                "list",
                "--resource-group",
                azure_resource_group,
                "--name",
                azure_key_vault_name,
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(res.stdout)
        ips = [ips["value"].split("/")[0] for ips in data["ipRules"]]
        return sorted(ips)
    except subprocess.CalledProcessError as e:
        print(e.stderr)
    exit(1)


# make system call to azure client to add or remove an IP address to the AKV Firewall / ACL
def change_azure_acl(ip: str, action: str) -> None:
    if action not in ["add", "remove"]:
        print(f"{action} is not one of supported actions: [ 'add', 'remove' ]")
        return

    try:
        res = subprocess.run(
            [
                "az",
                "keyvault",
                "network-rule",
                action,
                "--resource-group",
                azure_resource_group,
                "--name",
                azure_key_vault_name,
                "--ip-address",
                ip,
                "--only-show-errors",
            ],
            capture_output=True,
            text=True,
        )
        print(f"[change] {action} ip {ip}")
        return
    except subprocess.CalledProcessError as e:
        print(e.stderr)
    exit(1)


# get current Atlas IPs, current AKV Firewall / ACL IPs, compare them, then add and remove the necessary and unnecessary IPs respectively
def run() -> None:
    current_fw = get_azure_acl()
    if debug:
        print(f"current akv firewall: {current_fw}")
    current_ips = get_control_ips()
    current_ips.extend(get_host_ips())
    if debug:
        print(f"current atlas ips: {current_ips}")

    ips_to_add = [ip for ip in current_ips if ip not in current_fw]
    ips_to_remove = [ip for ip in current_fw if ip not in current_ips]

    if debug:
        print(f"ips_to_add: {ips_to_add}")
        print(f"ips_to_remove: {ips_to_remove}")

    for ip in ips_to_add:
        change_azure_acl(ip, "add")

    for ip in ips_to_remove:
        change_azure_acl(ip, "remove")


# this code is used as a cron simluation for demonstration purpose
def signal_handler(sig, frame) -> None:
    print("\nTerminating the script...")
    exit(0)


signal.signal(signal.SIGINT, signal_handler)

while True:
    run()
    print("-\n")
    time.sleep(2 * 60)
#
