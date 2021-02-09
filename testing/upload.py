import requests

endpoint = "http://localhost/api/upload"
data = {
  "content": "hello world"
}

resp = requests.post(endpoint, data=data)
print(resp.text)