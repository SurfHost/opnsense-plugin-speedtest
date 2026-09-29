<?php

/*
 * Copyright (c) 2026 SurfHost.nl
 * SPDX-License-Identifier: BSD-2-Clause
 */

/**
 * Scheduled test as a system cron job (see system_cron_configure() in core),
 * so nobody has to add one under System: Settings: Cron by hand. Saving the
 * settings runs 'configctl cron restart', which regenerates the crontab.
 */
function speedtestsurfhost_cron()
{
    $jobs = [];

    $fields = (new \OPNsense\SpeedtestSurfHost\SpeedtestSurfHost())->cronFields();
    if ($fields !== null) {
        $jobs[]['autocron'] = [
            '/usr/local/bin/python3 /usr/local/opnsense/scripts/OPNsense/SpeedtestSurfHost/speedtest.py run default',
            $fields[0],
            $fields[1],
        ];
    }

    return $jobs;
}
