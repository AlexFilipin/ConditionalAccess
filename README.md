# Conditional Access as Code

In an nutshell this repository does two things:
* It provides sets of conditional policies as JSON files that can be deployed to your tenant with a PowerShell script. The same script can also be used to update your conditional access policies and manage them as code.
* The wiki has plenty of information around designing conditional access policies and fitting them to your organization. While automation is a honorable goal you should first take care WHAT your policies should do, get the most esential policies enabled and develop your organiations strategy to further improve your maturity. Most likely an initial deployment of a policy set is more than enough before you dive into complex management as code.

# Get started with the [Quick-start wiki](https://github.com/AlexFilipin/ConditionalAccess/wiki#quick-start)

Although I work for Microsoft, this is not an official recommendation, I exclude any liability and warranty. This is only a personal recommendation which has to be implemented with the utmost care and testing.

# Supplementary information

## Policy sets
Policy sets are based on the policies in the repository and form complete policy sets depending on company maturity and licensing:
* Bare minimum
* Device trust with AADP1
* Device trust with AADP1 and AADP2
* Device trust with AADP2
* Your custom policy set

## Policy repository
A collection of conditional access policies in JSON format which are divided into the following categories:
* Admin protection
* Application protection
* Attack surface reduction
* Base protection
* Compliance
* Data protection

## Automation solution
A script based automation solution to deploy and update policy sets in environments.

**Together, these three components enable an extremely fast deployment of conditional access concepts and their long-term maintenance, e.g. in the form of source control.**

![Example policy set](https://i.imgur.com/g08eQN6.png)
