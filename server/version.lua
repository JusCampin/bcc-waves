local BccUtils = exports['bcc-utils'].initiate()

-- Version checker
BccUtils.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/BryceCanyonCounty/bcc-waves')
