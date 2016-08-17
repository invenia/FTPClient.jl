from OpenSSL import crypto, SSL
from socket import gethostname
from pprint import pprint
from time import gmtime, mktime
from os.path import exists, join

import logging
import argparse
from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.handlers import FTPHandler, TLS_FTPHandler
from pyftpdlib.servers import FTPServer

# Required packages: pyftpdlib, pyopenssl


# https://github.com/giampaolo/pyftpdlib/issues/160
class TLSImplicit_FTPHandler(TLS_FTPHandler):
    def handle(self):
        self.secure_connection(self.ssl_context)

    def handle_ssl_established(self):
        TLS_FTPHandler.handle(self)

    def ftp_AUTH(self, arg):
        self.respond("550 not supposed to be used with implicit SSL.")


def create_self_signed_cert(cert_dir, cert_file, key_file, hostname):
    # from https://gist.github.com/ril3y/1165038
    
    if not exists(join(cert_dir, cert_file)) \
            or not exists(join(cert_dir, key_file)):

        # create a key pair
        k = crypto.PKey()
        k.generate_key(crypto.TYPE_RSA, 1024)

        # create a self-signed cert
        cert = crypto.X509()
        cert.get_subject().CN = hostname
        cert.set_serial_number(1000)
        cert.gmtime_adj_notBefore(0)
        cert.gmtime_adj_notAfter(10*365*24*60*60)
        cert.set_issuer(cert.get_subject())
        cert.set_pubkey(k)
        cert.sign(k, 'sha1')

        with open(join(cert_dir, cert_file), "wt") as fp:
            fp.write(crypto.dump_certificate(crypto.FILETYPE_PEM, cert))
        with open(join(cert_dir, key_file), "wt") as fp:
            fp.write(crypto.dump_privatekey(crypto.FILETYPE_PEM, k))
        


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('username', type=str)
    parser.add_argument('password', type=str)
    parser.add_argument('root', type=str)
    parser.add_argument('--permissions', type=str, default="elr")
    parser.add_argument('--hostname', type=str, default="localhost")
    parser.add_argument('--port', type=int, default=0)
    parser.add_argument('--passive-ports', type=str)
    parser.add_argument('--tls', choices=['implicit', 'explicit'])
    parser.add_argument('--tls-require', choices=['control', 'data'], nargs='*', default=[])  # noqa
    parser.add_argument('--cert-file', type=str, default='test.crt')
    parser.add_argument('--key-file', type=str, default='test.key')
    parser.add_argument('--debug', type=bool, default=False)
    parser.add_argument('--gen-certs-dir', type=str, default='')

    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(level=logging.DEBUG)

    if args.gen_certs_dir:
        create_self_signed_cert(args.gen_certs_dir, args.cert_file, args.key_file, args.hostname)

    if args.passive_ports:
        passive = tuple(int(p) for p in args.passive_ports.split('-'))
        if len(passive) > 2:
            raise ValueError("Passive port needs to be a range of two values")

        if len(passive) == 1:
            args.passive_ports = range(passive[0], passive[0] + 1)
        else:
            args.passive_ports = range(passive[0], passive[1] + 1)

    # Adapted from: http://pythonhosted.org/pyftpdlib/tutorial.html#building-a-base-ftp-server  # noqa
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
