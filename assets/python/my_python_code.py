import json

#sample json code
color_data = [{'r': '255', 'g': '254', 'b': '233'} ]
json_data = json.dumps(color_data)

print(json_data)
