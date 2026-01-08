import Foundation

let CommonPortNames: [UInt16: String] = [
    20: "FTP-D", 21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP",
    53: "DNS", 67: "DHCP", 68: "DHCP", 69: "TFTP", 80: "HTTP",
    110: "POP3", 123: "NTP", 135: "EPMAP", 137: "NetBIOS-Ns",
    138: "NetBIOS-Dgm", 139: "NetBIOS", 143: "IMAP", 161: "SNMP",
    162: "SNMP-trap", 179: "BGP", 389: "LDAP", 443: "HTTPS",
    445: "SMB", 465: "SMTPS", 500: "ISAKMP", 514: "Syslog", 515: "LPD",
    587: "Submission", 631: "IPP", 636: "LDAPS", 993: "IMAPS", 995: "POP3S",
    1080: "SOCKS", 1433: "MSSQL", 1521: "Oracle", 1723: "PPTP", 1883: "MQTT",
    2049: "NFS", 2375: "Docker", 2376: "Docker TLS", 2483: "Oracle",
    2484: "Oracle TLS", 3000: "Node", 3128: "Proxy", 3268: "GC",
    3269: "GC TLS", 3306: "MySQL", 3389: "RDP", 4444: "Metasploit",
    5000: "UPnP", 5432: "Postgres", 5672: "AMQP", 5900: "VNC",
    5985: "WinRM", 5986: "WinRM TLS", 6379: "Redis", 7001: "WebLogic",
    8000: "HTTP-alt", 8080: "HTTP-alt", 8081: "HTTP-alt", 8443: "HTTPS-alt",
    8530: "WSUS", 8531: "WSUS TLS", 8888: "HTTP-alt", 9000: "SonarQube",
    9001: "Tor", 9100: "JetDirect", 9200: "Elasticsearch", 9300: "Elastic-Node",
    10000: "Webmin"
]
