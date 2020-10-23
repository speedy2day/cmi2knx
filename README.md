# cmi2knx
Fetch the Control and Monitoring Interface (C.M.I.) data via JSON API and write to Group Addresses on the KNX Bus

This is a little bash script I wrote, to cyclically fetch mainly temperatures, but also pressure and irradiance data from the Control and Monitoring Interface (C.M.I.) from the company Technische Alternative. The data is then converted to the KNX compliant DPT 9.x datapoint representation and sent to the KNX Bus using https://github.com/knxd/knxd or more precisely `knxtool groupwrite`.

The JSON API that is used on the C.M.I. side is described here: https://wiki.ta.co.at/C.M.I._JSON-API

Specification of the datapoint types used on the KNX Bus may be found here: [Datapoint Types - KNX Association](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&ved=2ahUKEwiImZSmz8vsAhWCsaQKHSxTCwgQFjAAegQIBhAC&url=https%3A%2F%2Fwww.knx.org%2FwAssets%2Fdocs%2Fdownloads%2FCertification%2FInterworking-Datapoint-types%2F03_07_02-Datapoint-Types-v02.01.02-AS.pdf&usg=AOvVaw1Sj0MeH30t81UNAIZd51KQ)

The script might be executed by cron every minute without any command line parameter given. At the end of the scipt a modulo on the current clock minute value takes care, so that every minute only one CAN bus member (behind the C.M.I.) is polled. This is a policy given by the C.M.I. JSON API.