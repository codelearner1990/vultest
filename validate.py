import subprocess
import json


def run_oc_command(command):
    """Run an oc CLI command and return the output."""
    result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        print(f"❌ Error executing command: {command}")
        print(result.stderr)
        return None
    return result.stdout.strip()

def get_pods_with_sidecar(namespace, sidecar_name):
    """Find all pods in a given namespace that have the KMS sidecar."""
    print(f"🔍 Searching for pods in namespace: {namespace} with sidecar: {sidecar_name}...")
    pods_json = run_oc_command(f"oc get pods -n {namespace} -o json")
    if not pods_json:
        return []

    pods = json.loads(pods_json)
    kms_pods = [
        pod["metadata"]["name"] for pod in pods["items"]
        if any(sidecar_name in c["name"].lower() for c in pod["spec"]["containers"])
    ]
    
    print(f"✅ Found {len(kms_pods)} pods with the sidecar.")
    return kms_pods

def list_certs_in_pod(pod_name, namespace, container_name):
    """List all certificate folders inside the PVC mount in the pod."""
    print(f"📂 Checking certificates in pod: {pod_name}, container: {container_name}...")
    certs_output = run_oc_command(f"oc exec {pod_name} -c {container_name} -n {namespace} -- ls {CERTS_DIR}")
    
    if certs_output:
        cert_folders = certs_output.splitlines()
        return cert_folders
    return None  # Return None if the directory does not exist

def main():
    print(f"\n🔍 Checking OpenShift Namespace: {NAMESPACE}\n")

    kms_pods = get_pods_with_sidecar(NAMESPACE, SIDECAR_NAME)
    if not kms_pods:
        print("❌ No KMS sidecar pods found.")
        return

    # Store results for validation
    cert_usage_map = {}

    print("\n📂 Listing all certificate folders inside KMS sidecar pods:")
    for pod in kms_pods:
        cert_folders = list_certs_in_pod(pod, NAMESPACE, SIDECAR_NAME)

        if cert_folders is not None:
            print(f"✅ {pod} contains cert folders: {cert_folders}")
            cert_usage_map[pod] = cert_folders
        else:
            print(f"❌ No cert folders found in {pod}. (PVC might not be mounted)")

    # Validate if SPECIFIC_CERT_FOLDER exists in any of the pods
    print(f"\n🔎 Checking if folder '{SPECIFIC_CERT_FOLDER}' exists in any pod:")
    found_in_pods = [pod for pod, folders in cert_usage_map.items() if SPECIFIC_CERT_FOLDER in folders]

    if found_in_pods:
        print(f"✅ Folder '{SPECIFIC_CERT_FOLDER}' is found in:")
        for pod in found_in_pods:
            print(f"- {pod}")
    else:
        print(f"❌ Folder '{SPECIFIC_CERT_FOLDER}' is NOT found in any KMS pods.")

if __name__ == "__main__":
    main()
