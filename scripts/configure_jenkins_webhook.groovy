assert id
assert value
assert hookUrl

def provider = com.cloudbees.plugins.credentials.SystemCredentialsProvider.getInstance()
def store = provider.getStore()
def managed = provider.getCredentials().findAll {
  it.description == 'GitHub webhook HMAC secret'
}
managed.each {
  store.removeCredentials(com.cloudbees.plugins.credentials.domains.Domain.global(), it)
}
def desired = new org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl(
  com.cloudbees.plugins.credentials.CredentialsScope.GLOBAL,
  id,
  'GitHub webhook HMAC secret',
  hudson.util.Secret.fromString(value)
)
assert store.addCredentials(
  com.cloudbees.plugins.credentials.domains.Domain.global(),
  desired
)

def config = jenkins.model.Jenkins.get().getDescriptorByType(
  org.jenkinsci.plugins.github.config.GitHubPluginConfig.class
)
config.setHookUrl(hookUrl)
config.setHookSecretConfigs([
  new org.jenkinsci.plugins.github.config.HookSecretConfig(id, 'HMAC_SHA256')
])
config.save()
assert config.hookSecretConfigs.size() == 1
assert config.hookSecretConfigs[0].credentialsId == id
assert config.hookSecretConfigs[0].signatureAlgorithmName == 'SHA256'