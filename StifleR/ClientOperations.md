# Configuring RBAC for Groups to in StifleR 2.10

In the StifleR.Service.exe.config File, you'll add a line like this:

```XML
<add key="ClientAdmins" value="2P\StifleR Client Admins:1048896"/>
```

The number after the colon will be the sum of the options you wish to enable.  The details are on the list below:


| Flag                  | Bit Position | Decimal Value (2ⁿ) |
|-----------------------|--------------|--------------------|
| None                 | N/A          | 0                  |
| WOL                  | 0            | 1                  |
| PowerShell           | 1            | 2                  |
| CommandLine          | 2            | 4                  |
| Downloads            | 3            | 8                  |
| Power                | 4            | 16                 |
| Connection           | 5            | 32                 |
| Cache                | 6            | 64                 |
| WMI                  | 7            | 128                |
| Logs                 | 8            | 256                |
| Users                | 9            | 512                |
| SRUMData             | 10           | 1024               |
| Variables            | 11           | 2048               |
| MeasureBandwidth     | 12           | 4096               |
| WiFi                 | 13           | 8192               |
| PerformanceCounters  | 14           | 16384              |
| Endpoints            | 15           | 32768              |
| ResourceMonitor      | 16           | 65536              |
| Processes            | 17           | 131072             |
| Disk                 | 18           | 262144             |
| PhysicalNetwork      | 19           | 524288             |
| RDP                  | 20           | 1048576            |
| Allrights            | 0–20         | 2097151            |


### Notes

- Each flag (except None) is calculated as 1 << n, where n is the bit position, resulting in 2ⁿ.

- The Allrights flag combines all flags from WOL to RDP (bits 0 through 20), which is 2²¹ - 1 = 2097151.

- To create a number from specific flags, use the bitwise OR operator (|) or sum their decimal values. For example, WOL | PowerShell | Downloads = 1 + 2 + 8 = 11.

