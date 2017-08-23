# exogeni-recipes
ExoGENI example scripts

In most recipes, the postboot script is presented as a separate file from the RDF request file.  This is not strictly necessary, as the RDF request file contains the postboot script for each node.  The postboot script is presented separately for ease of editing.  Any changes made to the postboot script will need to be manually copied into the RDF request file.  (Usually this will be done using Flukes, by editing the Node properties, and pasting in the postboot script.)

# References
- [Velocity Templates](https://github.com/RENCI-NRIG/orca5/wiki/velocity-templates)

