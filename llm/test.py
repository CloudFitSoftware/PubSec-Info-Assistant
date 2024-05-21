import requests

url = 'http://localhost:6001/predict'
headers = {'Content-Type': 'application/json'}
data = {'text': 'Who is Bill Gates? Please answer the question strictly using the information provided below \n Bill Gates is a Service Engineer at CloudFit. He works with Mike, Bryan, and Philip. He loves driving fast cars, skiing, and travelling. His favorite city is London. '}

response = requests.post(url, headers=headers, json=data)

print(response.text)