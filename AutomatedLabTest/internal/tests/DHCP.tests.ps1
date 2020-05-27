﻿param
(
    [Parameter()]
    [AutomatedLab.Lab]
    $Lab = $global:pesterLab
)

Describe "$($Lab.Name) DHCP" -Tag DHCP {

    Context "Role deployment successful" {
        It "Should return the correct amount of machines" {
            (Get-LabVm -Role DHCP).Count | Should -Be $Lab.Machines.Where({$_.Roles.Name -contains 'DHCP'}).Count
        }
    }
}
