New-AzManagementGroupDeployment -Name CustomerOnboardviaPolicy `
-Location AustraliaEast -ManagementGroupId 4005dec5-fb4a-48a2-9fd8-b22d223db569 `
-TemplateFile .\deployLighthousepolicy.json `
-TemplateParameterFile .\deployLighthousepolicy.parameters.json `
-WhatIf `
-Confirm:$false -Verbose