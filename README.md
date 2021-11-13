# Conditional Access as Code

In an nutshell this repository does two things:
* It provides sets of conditional policies as JSON files that can be deployed to your tenant with a PowerShell script. The same script can also be used to update your conditional access policies and manage them as code.
* The wiki has plenty of information around designing conditional access policies and fitting them to your organization. While automation is a honorable goal you should first take care WHAT your policies should do, get the most esential policies enabled and develop your organiations strategy to further improve your maturity. Most likely an initial deployment of a policy set is more than enough before you dive into complex management as code.

# Get started with the [Quick-start wiki](https://github.com/AlexFilipin/ConditionalAccess/wiki#quick-start)

Although I work for Microsoft, this is not an official recommendation, I exclude any liability and warranty. This is only a personal recommendation which has to be implemented with the utmost care and testing.

# Supplementary information

## [Policy repository](https://github.com/AlexFilipin/ConditionalAccess/tree/master/PolicyRepository)
A collection of conditional access policies in JSON format which are divided into the following categories and used for policy sets:
* Admin protection
* Application protection
* Attack surface reduction
* Base protection
* Compliance
* Data protection

You should NOT deploy all policies in the policy repository - deploy ONE policy set - for more information refer to the quick start wiki.

## [Policy sets](https://github.com/AlexFilipin/ConditionalAccess/tree/master/PolicySets)
Policy sets consist of several policies from the repository and form a blueprint of the conditional access policies your organization should have in place:
* Bare minimum
* Category structure for AADP1
* Category structure for AADP1 and AADP2 mixture
* Category structure for AADP2

## [PowerShell automation script](https://github.com/AlexFilipin/ConditionalAccess/blob/master/Deploy-Policies.ps1)
A script based automation solution to deploy and update policy sets.

**Together, these three components enable an extremely fast deployment of conditional access concepts and their long-term maintenance, e.g. in the form of source control.**

![Example policy set](https://i.imgur.com/9EfsHNk.png)
