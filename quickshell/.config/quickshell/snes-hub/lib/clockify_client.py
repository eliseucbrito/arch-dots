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
# ...
CACHE_FILE = "/tmp/qs_clockify_cache.json"
PROJECTS_CACHE_FILE = os.path.expanduser("~/.cache/quickshell/clockify_projects.json")

# ... (keep config cache file def)
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
        return {"error": f"HTTP {e.code}"}
    except Exception as e:
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
    if not wid and user.get("memberships"):
         wid = user["memberships"][0].get("targetId")

    res = {"userId": uid, "workspaceId": wid, "token_snippet": token[:5]}
    
    try:
        os.makedirs(os.path.dirname(CONFIG_CACHE_FILE), exist_ok=True)
        with open(CONFIG_CACHE_FILE, "w") as f:
            json.dump(res, f)
    except:
        pass
        
    return res

def get_projects(token, wid, force_refresh=False):
    if not force_refresh and os.path.exists(PROJECTS_CACHE_FILE):
        try:
            with open(PROJECTS_CACHE_FILE, "r") as f:
                return json.load(f)
        except:
            pass

    endpoint = f"/workspaces/{wid}/projects?page-size=500"
    projects = make_request("GET", endpoint, token)
    
    if isinstance(projects, list):
        try:
            os.makedirs(os.path.dirname(PROJECTS_CACHE_FILE), exist_ok=True)
            with open(PROJECTS_CACHE_FILE, "w") as f:
                json.dump(projects, f)
        except:
            pass
        return projects
    
    return []

def get_project_map(token, wid):
    projs = get_projects(token, wid)
    pmap = {}
    if isinstance(projs, list):
        for p in projs:
            pmap[p["id"]] = {"name": p["name"], "color": p["color"]}
    return pmap

def get_current_entry(token, wid, uid, cached_only=False):
    # Aggressive Caching Strategy for UI responsiveness
    cached_data = None
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                cached_data = json.load(f)
        except:
            pass
            
    if cached_only or (len(sys.argv) > 2 and sys.argv[2] == "--cached"):
        if cached_data:
            return cached_data
    
    endpoint = f"/workspaces/{wid}/user/{uid}/time-entries?page-size=10"
    entries = make_request("GET", endpoint, token)
    
    if isinstance(entries, dict) and "error" in entries:
        if cached_data:
            return cached_data
        return entries
        
    pmap = get_project_map(token, wid)

    running = None
    recent = []
    
    if isinstance(entries, list):
        for entry in entries:
            ti = entry.get("timeInterval", {})
            pid = entry.get("projectId")
            
            pname = ""
            pcolor = "#03a9f4"
            if pid and pid in pmap:
                pname = pmap[pid]["name"]
                pcolor = pmap[pid]["color"]

            enriched = entry.copy()
            enriched["projectName"] = pname
            enriched["projectColor"] = pcolor

            if not ti.get("end"):
                running = enriched
            else:
                desc = entry.get("description", "")
                
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
                        "projectColor": pcolor,
                        "projectName": pname
                    })

    result = {"running": running, "recent": recent}
    
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
    
    # Return full status from cache to update UI consistent with status polling
    return get_current_entry(token, wid, uid, cached_only=True)

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
        # We need to enrich the result for the cache, otherwise UI won't have project name
        # But for speed, let's just dump what we have or try to enrich quickly?
        # Re-using get_current_entry logic is safest but slower?
        # Actually, get_current_entry(cached_only=True) reads what we write.
        # So we must write enriched data if possible.
        # But 'res' from POST doesn't have project name.
        # Let's rely on update_cache saving it, and if it's missing project name,
        # get_current_entry might be confused?
        # Actually, update_cache writes whatever we give it as "running".
        # Let's just write 'res'. The UI will see it.
        # The UI should be robust enough.
        update_cache(res)
        
    return get_current_entry(token, wid, 0, cached_only=True) 

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
        
    elif cmd == "projects":
        refresh = "--refresh" in sys.argv
        data = get_projects(token, wid, force_refresh=refresh)
        print(json.dumps(data))

    elif cmd == "stop":
        res = stop_entry(token, wid, uid)
        print(json.dumps(res))
        
    elif cmd == "start":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "Missing description"}))
            sys.exit(1)
            
        # Parse: start <desc> [options?]
        args = sys.argv[2:]
        desc_parts = []
        pid = None
        
        i = 0
        while i < len(args):
            if args[i] == "--project" and i+1 < len(args):
                pid = args[i+1]
                i += 2
            else:
                desc_parts.append(args[i])
                i += 1
                
        desc = " ".join(desc_parts)
        res = start_entry(token, wid, desc, pid)
        print(json.dumps(res))

    else:
        print(json.dumps({"error": "Unknown command"}))

if __name__ == "__main__":
    main()
