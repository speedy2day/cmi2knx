# cmi2knx
Fetch the Control and Monitoring Interface (C.M.I.) data via JSON API and write to Group Addresses on the KNX Bus

This is a little bash script I wrote, to cyclically fetch mainly temperatures, but also pressure and irradiance from the Control and Monitoring Interface (C.M.I.) from the company Technische Alternative. The data is then converted to the KNX compliant DPT 9.x datapoint representation and sent to the KNX Bus using https://github.com/knxd/knxd or more precisely knxtool.
