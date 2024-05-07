from http.client import HTTPConnection
from urllib.parse import urlparse, parse_qs
import argparse


def main():
    parser = argparse.ArgumentParser(description="Tests AWS LB connections.")
    parser.add_argument("url")
    parser.add_argument("-c", "--count", type=int, default=10)
    parser.add_argument("-p", "--port", type=int, default=80)
    parser.add_argument("-k", "--keepCookies", nargs='+')
    args = parser.parse_args()

    parsed = urlparse(args.url)
    query_params = parse_qs(parsed.query)
    connection = HTTPConnection(parsed.netloc, args.port)
    keep = set(args.keepCookies) if args.keepCookies is not None else set()
    cookies = []
    url = "" if len(query_params) == 0 else f"/?{parsed.query}"
    print(parsed.netloc)
    for idx in range(0, args.count):
        headers = {
            "Cookie": "; ".join(cookies)
        } if len(cookies) > 0 else {}
        connection.request("GET", url, headers=headers)
        response = connection.getresponse()
        response_body = response.read()
        print(response.status, response_body)
        if idx == 0 and args.keepCookies is not None:
            for key, value in response.getheaders():
                if key.lower() == "set-cookie":
                    received_cookies = value.split("; ")
                    cookies.extend(list(filter(lambda cookie: cookie.split("=")[0] in keep, received_cookies)))

    connection.close()


if __name__ == "__main__":
    main()
