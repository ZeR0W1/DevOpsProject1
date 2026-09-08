if (!id || !value || !hookUrl) {
  throw new IllegalArgumentException(
    'Jenkins webhook configuration is missing a required injected value; verify the helper Job environment and Secrets.'
  )
}

try {
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
  if (!store.addCredentials(
    com.cloudbees.plugins.credentials.domains.Domain.global(),
    desired
  )) {
    throw new IllegalStateException('credential store rejected the managed credential')
  }
} catch (Exception ignored) {
  throw new IllegalStateException(
    'Jenkins webhook credential configuration failed; verify Credentials plugin health and controller permissions.'
  )
}

try {
  def config = jenkins.model.Jenkins.get().getDescriptorByType(
    org.jenkinsci.plugins.github.config.GitHubPluginConfig.class
  )
  config.setHookUrl(hookUrl)
  config.setHookSecretConfigs([
    new org.jenkinsci.plugins.github.config.HookSecretConfig(id, 'HMAC_SHA256')
  ])
  config.save()
  if (
    config.hookSecretConfigs.size() != 1 ||
    config.hookSecretConfigs[0].credentialsId != id ||
    config.hookSecretConfigs[0].signatureAlgorithmName != 'SHA256'
  ) {
    throw new IllegalStateException('saved GitHub plugin configuration did not verify')
  }
} catch (Exception ignored) {
  throw new IllegalStateException(
    'Jenkins GitHub plugin configuration failed; verify plugin health and the configured webhook endpoint.'
  )
}