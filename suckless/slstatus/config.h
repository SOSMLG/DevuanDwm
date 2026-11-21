/* See LICENSE file for copyright and license details. */

/* interval between updates (in ms) */
const unsigned int interval = 1000;

/* text to show if no value can be retrieved */
static const char unknown_str[] = "n/a";

/* pactl one-liners for the status bar — mute state short-circuits to "Off" */
static const char volcmd[] = "[ $(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}') = \"yes\" ] \
                             && printf 'Off' \
                             || pactl get-sink-volume @DEFAULT_SINK@ | awk -F'/' '{print $2}' | tr -d ' '";
static const char miccmd[] = "[ $(pactl get-source-mute @DEFAULT_SOURCE@ | awk '{print $2}') = \"yes\" ] \
                             && printf 'Off' \
                             || pactl get-source-volume @DEFAULT_SOURCE@ | awk -F'/' '{print $2}' | tr -d ' '";

/* maximum output string length */
#define MAXLEN 2048

/*
 * function            description                     argument (example)
 *
 * battery_perc        battery percentage              battery name (BAT0)
 *                                                     NULL on OpenBSD/FreeBSD
 * battery_remaining   battery remaining HH:MM         battery name (BAT0)
 *                                                     NULL on OpenBSD/FreeBSD
 * battery_state       battery charging state          battery name (BAT0)
 *                                                     NULL on OpenBSD/FreeBSD
 * cat                 read arbitrary file             path
 * cpu_freq            cpu frequency in MHz            NULL
 * cpu_perc            cpu usage in percent            NULL
 * datetime            date and time                   format string (%F %T)
 * disk_free           free disk space in GB           mountpoint path (/)
 * disk_perc           disk usage in percent           mountpoint path (/)
 * disk_total          total disk space in GB          mountpoint path (/)
 * disk_used           used disk space in GB           mountpoint path (/)
 * entropy             available entropy               NULL
 * gid                 GID of current user             NULL
 * hostname            hostname                        NULL
 * ipv4                IPv4 address                    interface name (eth0)
 * ipv6                IPv6 address                    interface name (eth0)
 * kernel_release      `uname -r`                      NULL
 * keyboard_indicators caps/num lock indicators        format string (c?n?)
 *                                                     see keyboard_indicators.c
 * keymap              layout (variant) of current     NULL
 *                     keymap
 * load_avg            load average                    NULL
 * netspeed_rx         receive network speed           interface name (wlan0)
 * netspeed_tx         transfer network speed          interface name (wlan0)
 * num_files           number of files in a directory  path
 *                                                     (/home/foo/Inbox/cur)
 * ram_free            free memory in GB               NULL
 * ram_perc            memory usage in percent         NULL
 * ram_total           total memory size in GB         NULL
 * ram_used            used memory in GB               NULL
 * run_command         custom shell command            command (echo foo)
 * swap_free           free swap in GB                 NULL
 * swap_perc           swap usage in percent           NULL
 * swap_total          total swap size in GB           NULL
 * swap_used           used swap in GB                 NULL
 * temp                temperature in degree celsius   sensor file
 *                                                     (/sys/class/thermal/...)
 *                                                     NULL on OpenBSD
 *                                                     thermal zone on FreeBSD
 *                                                     (tz0, tz1, etc.)
 * uid                 UID of current user             NULL
 * up                  interface is running            interface name (eth0)
 * uptime              system uptime                   NULL
 * username            username of current user        NULL
 * vol_perc            OSS/ALSA volume in percent      mixer file (/dev/mixer)
 *                                                     NULL on OpenBSD/FreeBSD
 * wifi_essid          WiFi ESSID                      interface name (wlan0)
 * wifi_perc           WiFi signal in percent          interface name (wlan0)
 */
static const struct arg args[] = {
	/* function format          argument */
	{ wifi_perc,    "^c#9A9AA2^ 󰤨 ^c#FFFFFF^%s%% ", "wlan0" },
	{ cpu_perc,     "^c#E8A33D^ 󰻠 ^c#FFFFFF^%s%% ", NULL },
	{ ram_perc,     "^c#9A9AA2^ 󰍛 ^c#FFFFFF^%s%% ", NULL },
	{ disk_perc,    "^c#8FB57A^ 󰋊 ^c#FFFFFF^%s%% ", "/" },
	{ run_command,  "^c#E8A33D^ 󰕾 ^c#FFFFFF^%s ", volcmd },
	{ run_command,  "^c#9A9AA2^ 󰍬 ^c#FFFFFF^%s ", miccmd },
	{ battery_perc, "^c#7E9DB5^ 󰁹 ^c#FFFFFF^%s%% ", "BAT0" },
	{ battery_state,"^c#E8A33D^ 󰂄 ^c#FFFFFF^%s ", "BAT0" },
	{ datetime,     "^c#D8D3C8^ 󰸗 ^c#FFFFFF^%s ", "%a %b %-d" },
	{ datetime,     "^c#D8D3C8^ 󰥔 ^c#FFFFFF^%s  ", "%-l:%M %p" },
	};
