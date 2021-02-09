import requests
import sys

endpoint = "http://localhost/api/fetch"
params = {
  "code": sys.argv[1]
}

resp = requests.get(endpoint, params=params)
print(resp.text)