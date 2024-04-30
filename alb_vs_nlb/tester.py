from http.client import HTTPConnection
import argparse


def main():
    parser = argparse.ArgumentParser(description="Tests AWS LB connections.")
    parser.add_argument("domain")
    parser.add_argument("-c", "--count", default=10)
    parser.add_argument("-p", "--port", default=80)
    args = parser.parse_args()

    connection = HTTPConnection(args.domain, args.port)
    for _ in range(0, args.count):
        connection.request("GET", "")
        response = connection.getresponse()
        response_body = response.read()
        print(response.status, response_body)
    connection.close()


if __name__ == "__main__":
    main()
