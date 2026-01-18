#!/usr/bin/env python3

import os
import sys
import json
import time
import urllib.request
import urllib.error
import socket

# Config constants
TOKEN_FILE = os.path.expanduser("~/.config/quickshell/clockify_token")
API_BASE = "https://api.clockify.me/api/v1"
CACHE_FILE = "/tmp/qs_clockify_cache.json"

# We can cache critical IDs (workspace, user) to save startup roundtrips
CONFIG_CACHE_FILE = os.path.expanduser("~/.cache/quickshell/clockify_config.json")

def get_token():
    try:
        with open(TOKEN_FILE, "r") as f:
            return f.read().strip()
    except FileNotFoundError:
        return None

def get_headers(token):
    return {
        "X-Api-Key": token,
        "Content-Type": "application/json"
    }

def make_request(method, endpoint, token, data=None):
    url = f"{API_BASE}{endpoint}"
    headers = get_headers(token)
    
    body = None
    if data:
        body = json.dumps(data).encode("utf-8")

    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 204: 
                return None
            return json.load(response)
    except urllib.error.HTTPError as e:
        # print(f"HTTP Error: {e.code} {e.reason}", file=sys.stderr)
        return {"error": f"HTTP {e.code}"}
    except Exception as e:
        # print(f"Error: {str(e)}", file=sys.stderr)
        return {"error": str(e)}

def get_user_and_workspace(token):
    # Check cache first
    if os.path.exists(CONFIG_CACHE_FILE):
        try:
            with open(CONFIG_CACHE_FILE, "r") as f:
                cached = json.load(f)
                if cached.get("token_snippet") == token[:5]:
                    return cached
        except:
            pass

    # Fetch from API
    user = make_request("GET", "/user", token)
    if not user or "id" not in user:
        return None

    uid = user["id"]
    wid = user["activeWorkspace"]
    # Provide a fallback if activeWorkspace is missing, pick the first one
    if not wid and user.get("memberships"):
         wid = user["memberships"][0].get("targetId")

    res = {"userId": uid, "workspaceId": wid, "token_snippet": token[:5]}
    
    # Save cache
    try:
        os.makedirs(os.path.dirname(CONFIG_CACHE_FILE), exist_ok=True)
        with open(CONFIG_CACHE_FILE, "w") as f:
            json.dump(res, f)
    except:
        pass
        
    return res

def get_current_entry(token, wid, uid):
    # Aggressive Caching Strategy for UI responsiveness
    # 1. Try to read cache immediately
    cached_data = None
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                cached_data = json.load(f)
        except:
            pass
            
    # If the user just wants the 'cached' version for instant UI load
    if len(sys.argv) > 2 and sys.argv[2] == "--cached":
        if cached_data:
            return cached_data
        # Fallthrough to fetch if no cache
    
    # 2. Fetch from API
    endpoint = f"/workspaces/{wid}/user/{uid}/time-entries?page-size=10"
    entries = make_request("GET", endpoint, token)
    
    if isinstance(entries, dict) and "error" in entries:
        # On error, return cache if available as fallback?
        if cached_data:
            return cached_data
        return entries
        
    running = None
    recent = []
    
    if isinstance(entries, list):
        for entry in entries:
            ti = entry.get("timeInterval", {})
            if not ti.get("end"):
                running = entry
            else:
                desc = entry.get("description", "")
                pid = entry.get("projectId")
                
                exists = False
                for r in recent:
                    if r.get("description") == desc and r.get("projectId") == pid:
                        exists = True
                        break
                
                if not exists and len(recent) < 5:
                    recent.append({
                        "id": entry.get("id"),
                        "description": desc,
                        "projectId": pid,
                        "projectColor": "#03a9f4",
                        "projectName": ""
                    })

    result = {"running": running, "recent": recent}
    
    # 3. Write to Cache
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump(result, f)
    except:
        pass

    return result

    # ... (existing code)

def update_cache(running_entry, recent_entries=None):
    # Read existing first to preserve recent if not provided
    existing = {}
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                existing = json.load(f)
        except:
            pass
            
    recent = recent_entries if recent_entries is not None else existing.get("recent", [])
    
    new_cache = {
        "running": running_entry,
        "recent": recent
    }
    
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump(new_cache, f)
    except:
        pass

def stop_entry(token, wid, uid):
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    endpoint = f"/workspaces/{wid}/user/{uid}/time-entries"
    
    res = make_request("PATCH", endpoint, token, {"end": now})
    
    # Update cache immediately: Running is None
    if res and not isinstance(res, dict) or (isinstance(res, dict) and not "error" in res):
         update_cache(None)
         
    return res

def start_entry(token, wid, description, project_id=None):
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    endpoint = f"/workspaces/{wid}/time-entries"
    
    payload = {
        "start": now,
        "description": description,
        "billable": False
    }
    if project_id:
        payload["projectId"] = project_id
        
    res = make_request("POST", endpoint, token, payload)
    
    # Update cache immediately: Running is new entry
    if res and "id" in res:
        update_cache(res)
        
    return res

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: clockify_client.py [status|start <desc>|stop|resume <desc>]"}))
        sys.exit(1)

    token = get_token()
    if not token:
        print(json.dumps({"error": "No token found in ~/.config/quickshell/clockify_token"}))
        sys.exit(1)

    ctx = get_user_and_workspace(token)
    if not ctx:
        print(json.dumps({"error": "Could not determine user/workspace"}))
        sys.exit(1)
        
    wid = ctx["workspaceId"]
    uid = ctx["userId"]
    
    cmd = sys.argv[1]
    
    if cmd == "status":
        data = get_current_entry(token, wid, uid)
        print(json.dumps(data))
        
    elif cmd == "stop":
        res = stop_entry(token, wid, uid)
        print(json.dumps(res))
        
    elif cmd == "start":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "Missing description"}))
            sys.exit(1)
        desc = " ".join(sys.argv[2:])
        # Check if desc matches a recent entry with project? For now just simple start
        res = start_entry(token, wid, desc)
        print(json.dumps(res))

    else:
        print(json.dumps({"error": "Unknown command"}))

if __name__ == "__main__":
    main()
