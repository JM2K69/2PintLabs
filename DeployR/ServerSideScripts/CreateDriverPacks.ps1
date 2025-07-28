Import-Module 'C:\Program Files\2Pint Software\DeployR\Client\PSModules\DeployR.Utility'
Set-DeployRHost -Url "https://214-DeployR.2p.garytown.com:7281"




#ASSUMES YOU ALREADY HAVE A Driver Pack Content Item Created, just empty

#Grab the Content ID from that Content Item
$ContentId = 'aa4b8df6-1c3d-4720-bd59-05c12a2b7ed9'

#Folder Path of the Source Files you want to upload into that Content Item
$FolderPath = 'C:\Users\gary.blok\Downloads\55GJ_Mk3_Win11_24H2_V4_CAB\drivers'

#Command to update the content of the Content Item with the files in the folder
Update-DeployRContentItemContent -ContentId $ContentId -ContentVersion 1 -SourceFolder $FolderPath -Verbose
