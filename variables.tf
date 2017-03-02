variable aws_region {
  default = "us-west-2"
}

variable aws_profile {
  default = "default"
}

variable lambci_instance {
  default = "lambci"
}

variable lambci_version {
  default = "0.9.10"
}

variable GithubToken {
  description = "Must be empty or a 40 char GitHub Token"
}

variable Repositories {
  description = "(Optional) Github repos to add hook to, eg: facebook/react,emberjs/ember.js"
  default     = ""
}

variable SlackToken {
  description = "(optional) Slack API token"
  default     = ""
}

variable SlackChannel {
  description = "(optional) Slack channel"
  default     = "#general"
}


