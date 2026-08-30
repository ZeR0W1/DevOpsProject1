import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import hudson.util.Secret
import jenkins.model.Jenkins
import org.jenkinsci.plugins.github.config.GitHubPluginConfig
import org.jenkinsci.plugins.github.config.HookSecretConfig
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl


def id = System.getenv('WEBHOOK_CREDENTIALS_ID')
def value = System.getenv('WEBHOOK_SECRET')
def hookUrl = System.getenv('WEBHOOK_URL')
assert id
assert value
assert hookUrl

def provider = SystemCredentialsProvider.getInstance()
def store = provider.getStore()
def managed = provider.getCredentials().findAll {
  it.description == 'GitHub webhook HMAC secret'
}
managed.each { store.removeCredentials(Domain.global(), it) }
def desired = new StringCredentialsImpl(
  CredentialsScope.GLOBAL,
  id,
  'GitHub webhook HMAC secret',
  Secret.fromString(value)
)
assert store.addCredentials(Domain.global(), desired)

def config = Jenkins.get().getDescriptorByType(GitHubPluginConfig.class)
config.setHookUrl(hookUrl)
config.setHookSecretConfigs([new HookSecretConfig(id, 'HMAC_SHA256')])
config.save()
assert config.hookSecretConfigs.size() == 1
assert config.hookSecretConfigs[0].credentialsId == id
assert config.hookSecretConfigs[0].signatureAlgorithmName == 'SHA256'