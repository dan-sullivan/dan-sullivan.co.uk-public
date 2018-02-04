CONTENTTYPE_MAP = {
    "js": "application/javascript",
    "html": "text/html",
    "css": "text/css",
    "ico": "image/x-icon"
    }

def handler(event, context):
    if event == "cli":
        prefix_path = "../"
        event = {'resource': '/dscouk/{proxy+}', 'path': '/dscouk/lambda/index.html', 'httpMethod': 'GET', 'headers': {}}
    else:
        prefix_path = ""
    try:
        response = open(prefix_path + "dist/" + "/".join(event["path"].split("/")[3:]), "r").read()
        statusCode = "200"
        contentType = CONTENTTYPE_MAP[event["path"].split(".")[-1]]
    except:
        statusCode = "404"
        response = "<h1>404</h1>"
        contentType = "text/html; charset=utf-8"

    return { "statusCode": statusCode,
             "headers": {
                "Content-Type": contentType,
                        },
            "body": response
           }

if __name__ == '__main__':
    print(handler("cli", ""))
