@{
    Severity = @('Error','Warning')
    IncludeRules = @(
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSAvoidUsingAllowUnencryptedAuthentication',
        'PSAvoidUsingBrokenHashAlgorithms',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidGlobalVars',
        'PSAvoidDefaultValueSwitchParameter'
    )
}
