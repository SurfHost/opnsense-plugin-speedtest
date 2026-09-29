<?php

/*
 * Copyright (c) 2026 SurfHost.nl
 * SPDX-License-Identifier: BSD-2-Clause
 */

namespace OPNsense\SpeedtestSurfHost;

use OPNsense\Base\BaseModel;

class SpeedtestSurfHost extends BaseModel
{
    /**
     * Cron fields [minute, hour] for the configured schedule, or null when
     * scheduling is off. Every N hours starts at hour 0, so "every 6 hours"
     * runs at 0, 6, 12 and 18 past the chosen minute; once a day uses the
     * chosen hour.
     * @return array|null
     */
    public function cronFields()
    {
        if ((string)$this->schedule->enabled !== '1') {
            return null;
        }
        $minute = (string)(int)(string)$this->schedule->minute;
        $every = (int)substr((string)$this->schedule->interval, 1);
        if ($every >= 24) {
            return [$minute, (string)(int)(string)$this->schedule->hour];
        }
        return [$minute, $every <= 1 ? '*' : '*/' . $every];
    }
}
