<?php

/*
 * Copyright (c) 2026 SurfHost.nl
 * SPDX-License-Identifier: BSD-2-Clause
 */

namespace OPNsense\SpeedtestSurfHost\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'speedtestsurfhost';
    protected static $internalModelClass = '\OPNsense\SpeedtestSurfHost\SpeedtestSurfHost';
}
