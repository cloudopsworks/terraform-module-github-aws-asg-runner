/**
 * Lambda function to process GitHub Webhooks events
 *  Uses AWS SDK v3 and GitHub octokit
 * Webhooks that will be processed:
 *   - workflow_run, action: requested
 *   - workflow_job, action: queued
 * GitHub App Authentication is used to authenticate with GitHub API, id, private_key and installation_id are stored in a json at AWS Secrets Manager Secret
 * Event will be recevied from GitHub and processed by Lambda function as documented in https://docs.github.com/en/developers/webhooks-and-events/webhooks/webhook-events-and-payloads
 * Event will be received through AWS Lambda URL
 *
 * @author berahac
 */
const oktokit = require('@octokit/rest');
const octokitApp = require('@octokit/app');
const ec2 = require('@aws-sdk/client-ec2');
const secrets = require('@aws-sdk/client-secrets-manager');

// Initialize EC2 client
const ec2Client = new ec2.EC2Client();
const secretsClient = new secrets.SecretsManagerClient();
const secretName = process.env.get('GITHUB_APP_SECRET_NAME', 'github_app_credentials');

console.log(`Github App Secret Name: ${secretName}`);

// retrieve github app credentials from secrets manager
const ghappCredentials = async(secretName) => {
    const command = new secrets.GetSecretValueCommand({ SecretId: secretName });
    const response = await secretsClient.send(command);
    return JSON.parse(response.SecretString);
}

const secret = await getSecret(secretName);
console.log(`Retrieved GitHub App: ID=${secret.id} , Installation ID=${secret.installation_id} , PrivateKey=<<REDACTED>>`);
// Initialize octokit with app authentication
// async initialization of octokit with app authentication
// the appid, and private key are stored in secrets manager, privatekey comes base64 encoded
const octoapp = await octokitApp({
    appId: ghappCredentials.id,
    installationId: ghappCredentials.installation_id,
    privateKey: Buffer.from(ghappCredentials.private_key, 'base64').toString('utf8'),
});

const octokit = await octoapp.getInstallationOctokit(ghappCredentials.installation_id);

/**
 * Lambda handler for processing GitHub Webhooks events
 * Will process the events Workflows and Jobs in order to check if there is ASG availability to process
 * @param {Object} event - Input event containing order details
 * @param {Object} context - Lambda context object
 * @returns {Promise<string>} Success message
 */
export const handler = async(event, context) => {
    console.debug(`Event: ${JSON.stringify(event)}`);
    let response = {
        message: 'Success'
    };
    return JSON.stringify(response);
}