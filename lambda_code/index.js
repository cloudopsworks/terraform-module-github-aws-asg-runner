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
import { App } from '@octokit/app';
import { EC2Client }  from '@aws-sdk/client-ec2';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

// Initialize AWS SDK clients
const ec2Client = new EC2Client();
const secretsClient = new SecretsManagerClient();
const secretName = process.env.GITHUB_APP_SECRET_NAME || 'github_app_credentials';

console.log(`Github App Secret Name: ${secretName}`);

// Lazy initializer for GitHub App installation client
let cachedOctokit = null;
async function getInstallationOctokit() {
    if (cachedOctokit) return cachedOctokit;

    const command = new GetSecretValueCommand({ SecretId: secretName });
    const response = await secretsClient.send(command);
    const creds = JSON.parse(response.SecretString);

    console.log(`Retrieved GitHub App: ID=${creds.id} , Installation ID=${creds.installation_id} , PrivateKey=<<REDACTED>>`);

    const app = new App({
        appId: creds.id,
        privateKey: Buffer.from(creds.private_key, 'base64').toString('utf8'),
    });

    cachedOctokit = await app.getInstallationOctokit(creds.installation_id);
    return cachedOctokit;
}

/**
 * Lambda handler for processing GitHub Webhooks events
 * Will process the events Workflows and Jobs in order to check if there is ASG availability to process
 * @param {Object} event - Input event containing order details
 * @param {Object} context - Lambda context object
 * @returns {Promise<string>} Success message
 */
export const handler = async (event, context) => {
    console.debug(`Event: ${JSON.stringify(event)}`);

    // Initialize Octokit (lazy) in case it is needed later for API calls
    try {
        await getInstallationOctokit();
    } catch (err) {
        console.error('Failed to initialize GitHub App client:', err);
        // Do not fail the entire request unless required; adjust as needed
    }

    const response = {
        message: 'Success'
    };
    return JSON.stringify(response);
};