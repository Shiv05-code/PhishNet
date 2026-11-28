"""Per-user Live Monitoring entries in ONE Secrets Manager secret.

Secret `phishnet/monitor-tokens` holds a JSON object keyed by user ID:
  {"<uid>": {"refresh_token": "...", "history_id": "...", "lease_until": 0,
             "status": "ok" | "reauth_needed", "pending": {...}}}

One secret keeps cost at about $0.40/month for any number of users. Writes
are read-modify-write. The connect flow and the daily poll rarely overlap,
so the risk of a lost update is accepted for this scale.

Never log entries. They hold refresh tokens.
"""

import json

SECRET_NAME = "phishnet/monitor-tokens"


class MonitorStore:
    def __init__(self, sm_client, name=SECRET_NAME):
        self._sm = sm_client
        self._name = name

    def _read(self):
        try:
            raw = self._sm.get_secret_value(SecretId=self._name)["SecretString"]
        except self._sm.exceptions.ResourceNotFoundException:
            return {}
        return json.loads(raw) if raw else {}

    def _write(self, data):
        value = json.dumps(data, separators=(",", ":"))
        try:
            self._sm.put_secret_value(SecretId=self._name, SecretString=value)
        except self._sm.exceptions.ResourceNotFoundException:
            self._sm.create_secret(Name=self._name, SecretString=value)

    def get(self, uid):
        return dict(self._read().get(uid) or {})

    def put(self, uid, entry):
        data = self._read()
        data[uid] = entry
        self._write(data)

    def delete(self, uid):
        data = self._read()
        if data.pop(uid, None) is not None:
            self._write(data)

    def users(self):
        return [uid for uid, entry in self._read().items() if entry.get("refresh_token")]
