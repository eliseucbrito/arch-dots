#!/usr/bin/env python3

import os
import sys
import json
import time
import base64
import urllib.request
import urllib.parse
import urllib.error

# Config constants
TOKEN_FILE = os.path.expanduser("~/.config/quickshell/toggl_token")
CACHE_FILE = "/tmp/qs_toggl_cache.json"
CACHE_TTL = 120  # 2 minutes in seconds (30 reqs/hour limit => 1 req per 2 min)
API_BASE = "https://api.track.toggl.com/api/v9"

def get_token():
    try:
        with open(TOKEN_FILE, "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        return None

def get_auth_header(token):
    # Toggl Basic Auth: token:api_token
    auth_str = f"{token}:api_token"
    b64_auth = base64.b64encode(auth_str.encode("utf-8")).decode("utf-8")
    return {"Authorization": f"Basic {b64_auth}", "Content-Type": "application/json"}

def load_cache():
    if not os.path.exists(CACHE_FILE):
        return None
    try:
        with open(CACHE_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return None

def save_cache(data):
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump({"timestamp": time.time(), "data": data}, f)
    except Exception:
        pass

def make_request(method, endpoint, data=None):
    token = get_token()
    if not token:
        return {"error": "No token found"}

    url = f"{API_BASE}{endpoint}"
    headers = get_auth_header(token)
    
    body = None
    if data:
        body = json.dumps(data).encode("utf-8")

    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 204: # No content
                return None
            return json.load(response)
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}: {e.reason}"}
    except Exception as e:
        return {"error": str(e)}

def get_current_time_entry(force=False):
    # Check cache first
    cache = load_cache()
    if not force and cache:
        age = time.time() - cache.get("timestamp", 0)
        if age < CACHE_TTL:
            return cache.get("data")
            
    # Fetch from API
    response = make_request("GET", "/me/time_entries/current")
    
    # Save to cache if successful
    if isinstance(response, dict) and "error" not in response:
        save_cache(response)
        
    return response

def start_time_entry(description):
    # Need workspace ID first. usually just taking the first one is fine for simple use
    # But for simplicity, let's try to start without workspace id if possible, 
    # or get it from the 'me' endpoint if we cache it.
    # Actually Toggl v9 requires workspace_id for creating time entries.
    
    # Let's try to cache workspace id too or fetch it.
    # For now, let's just fetch 'me' to get default workspace
    me = make_request("GET", "/me")
    if not me or "default_workspace_id" not in me:
        return {"error": "Could not determine default workspace"}
        
    wid = me["default_workspace_id"]
    
    payload = {
        "description": description,
        "workspace_id": wid,
        "created_with": "quickshell-snes-hub",
        "start": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "duration": -1,
        "tags": [],
        "billable": False
    }
    
    res = make_request("POST", f"/workspaces/{wid}/time_entries", payload)
    
    # Invalidate cache/update it immediately
    if isinstance(res, dict) and "id" in res:
         save_cache(res)
         
    return res

def stop_time_entry():
    current = get_current_time_entry(force=True)
    if not current or "id" not in current:
        return {"error": "No running timer"}
        
    wid = current["workspace_id"]
    tid = current["id"]
    
    res = make_request("PATCH", f"/workspaces/{wid}/time_entries/{tid}/stop")
    
    # Update cache to show stopped (null)
    save_cache(None)
    
    return res

def main():
    if len(sys.argv) < 2:
        print("Usage: toggl_client.py [status|start <desc>|stop]")
        sys.exit(1)
        
    cmd = sys.argv[1]
    
    if cmd == "status":
        res = get_current_time_entry()
        print(json.dumps(res))
        
    elif cmd == "start":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "Missing description"}))
            sys.exit(1)
        desc = " ".join(sys.argv[2:])
        res = start_time_entry(desc)
        print(json.dumps(res))
        
    elif cmd == "stop":
        res = stop_time_entry()
        print(json.dumps(res))
        
    else:
        print(json.dumps({"error": "Unknown command"}))

if __name__ == "__main__":
    main()
