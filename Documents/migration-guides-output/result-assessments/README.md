## Migration Guide Result Assessments

The documents in this folder are used to assess the results of the validation.
Particularly, we want to assess the failure/success rate of the resulting Migration Guides.
To do so, we add inline annotations to the Migration Guide denoting result quality classifications.
As this is a manual process, we created copies of those migration guides in this folder to prevent them 
being overwritten from our automated validation util.

To assess the quality of change comparison we add the `result` field at the root of every change
type to annotate it with the corresponding result classification.
We consider the following result classification types:
- `success`: No failure occurred and this change and its classifications are considered a success.
- `success-duplicate`: Changes (and therefore models) are duplicated because they were described inline in the OAS document
   and therefore are considered multiple different entities. This result is still considered a success for evaluating the change comparison process.
   It just means, the resulting client library would be bloated and the resulting change stats are a bit off.
- `property-breaking-classification-inaccuracy`: A recorded change where the breaking classification isn't accurate, as the added 
   or removed property is only used in a response or request type respectively. The generated conversion scripts are not considered
   for the `conversion-manual-adjustments` classification as they are never used.
- `conversion-manual-adjustments`: A change which includes some sort of script based conversion (e.g. changed response type or field type; fallback or default values).
   The change is described properly and is classified as solvable. However, the generated script needs manual review and modifications.
   It may also include changes which provide an autogenerated default value or fallback value as we can't guarantee that
   these values will work in every case. Therefore, those values need manual review as well.
- `ill-classified-idchange`: A change which was wrongfully classified as a 'rename' change.
- `ill-classified-idchange-caused`: This result classification annotates changes which are the result of an ill-classified
  `idChange` (e.g., type changes, necessity change, ...).

This folder contains a `count.js` script file (to be executed with Node.js) which can be used to count all the stats
and output a latex table formatting to standard output. 