
$DeploymentLimit = 500

Login-AzureRmAccount

$Subscriptions = Get-AzureRmSubscription | Sort-Object -Property SubscriptionName

ForEach ($Subscription in $Subscriptions)
{
    Write-Host
    Write-Host
    Write-Host
    Write-Host "***********************************************************************************"
    Write-Host "**** Subscription: $($Subscription.SubscriptionName)"
    Write-Host "***********************************************************************************"
    Select-AzureRmSubscription -SubscriptionName $Subscription.SubscriptionName
    $ResourceGroups = Get-AzureRmResourceGroup

    ForEach ($ResourceGroup in $ResourceGroups)
    {
        Write-Host
        Write-Host "ResourceGroup: $($ResourceGroup.ResourceGroupName)"
        $Deployments = Get-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroup.ResourceGroupName

        Write-Host "Deployment Count: $($Deployments.Count)"
        If ($Deployments.Count -gt $DeploymentLimit)
        {
            Write-Host "Performing Cleanup..."

            $NumberToClean = $Deployments.Count - $DeploymentLimit

            $Deployments = $Deployments | Sort-Object -Property Timestamp | Select-Object -First $NumberToClean
            Write-Host "Number to Clean: $($Deployments.Count)"

            ForEach ($Deployment in $Deployments)
            {
                Write-Host "Deleting Deployment: '$($Deployment.DeploymentName)' From $($Deployment.Timestamp)"
                Remove-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroup.ResourceGroupName -Name $Deployment.DeploymentName | Out-Null
            }
        }
        Else
        {
            Write-Host "Skipping.  Deployment Count Is Under Limit."
        }
    }
}