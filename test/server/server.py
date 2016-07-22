import logging
import argparse
from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.handlers import FTPHandler, TLS_FTPHandler
from pyftpdlib.servers import FTPServer

# Required packages: pyftpdlib, pyopenssl


class TLSImplicit_FTPHandler(TLS_FTPHandler):
    def handle(self):
        self.secure_connection(self.ssl_context)

    def handle_ssl_established(self):
        TLS_FTPHandler.handle(self)

    def ftp_AUTH(self, arg):
        self.respond("550 not supposed to be used with implicit SSL.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('user', type=str)
    parser.add_argument('--hostname', type=str, default="127.0.0.1")
    parser.add_argument('--port', type=int, default=0)
    parser.add_argument('--passive-ports', type=str)
    parser.add_argument('--tls', choices=['implicit', 'explicit'])
    parser.add_argument('--tls-require', choices=['control', 'data'], nargs='*', default=[])  # noqa
    parser.add_argument('--cert-file', type=str, default='test.crt')
    parser.add_argument('--key-file', type=str, default='test.key')
    parser.add_argument('--debug', type=bool, default=False)

    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(level=logging.DEBUG)

    user = args.user.split(':')
    args.username, args.password, args.root = user[0:3]
    args.permissions = user[3] if len(user) >= 4 else "elr"

    if args.passive_ports:
        passive = tuple(int(p) for p in args.passive_ports.split('-'))
        if len(passive) > 2:
            raise ValueError("Passive port needs to be a range of two values")

        if len(passive) == 1:
            args.passive_ports = range(passive[0], passive[0] + 1)
        else:
            args.passive_ports = range(passive[0], passive[1] + 1)

    authorizer = DummyAuthorizer()
    authorizer.add_user(
        args.username,
        args.password,
        args.root,
        perm=args.permissions,
    )

    if args.tls == 'implicit':
        handler = TLSImplicit_FTPHandler
    elif args.tls == 'explicit':
        handler = TLS_FTPHandler
    else:
        handler = FTPHandler

    handler.authorizer = authorizer
    handler.passive_ports = args.passive_ports

    if args.tls:
        handler.certfile = args.cert_file
        handler.keyfile = args.key_file
        handler.tls_control_required = 'control' in args.tls_require
        handler.tls_data_required = 'data' in args.tls_require

    server = FTPServer((args.hostname, args.port), handler)
    server.serve_forever()
