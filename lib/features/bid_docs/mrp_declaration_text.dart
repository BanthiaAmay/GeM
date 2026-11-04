/// Text builder for the MRP Declaration Letter.
/// Declares the Maximum Retail Price of products offered in a GeM bid.
library;

import 'dart:typed_data';

import 'letter_model.dart';
import 'mii_certificate_text.dart' show formatLetterDate;

class MrpProductEntry {
  final String productName;
  final String brandName;
  final String modelNo;
  final String mrp;
  final Uint8List? imageBytes;

  const MrpProductEntry({
    required this.productName,
    required this.brandName,
    required this.modelNo,
    required this.mrp,
    this.imageBytes,
  });
}

class MrpDeclarationInput {
  final List<MrpProductEntry> products;
  final DateTime date;

  const MrpDeclarationInput({required this.products, required this.date});
}

/// Builds the full list of [LetterBlock]s for the MRP Declaration Letter.
/// For a single product with image this produces 21 blocks.
List<LetterBlock> buildMrpDeclarationLetter(MrpDeclarationInput input) {
  final blocks = <LetterBlock>[];

  blocks.add(
    LetterBlock.plain(LetterBlockKind.date, formatLetterDate(input.date)),
  );
  blocks.add(const LetterBlock.spacer());

  blocks.add(
    LetterBlock(LetterBlockKind.titleUnderlined, const [
      LetterSpan('DECLARATION OF MAXIMUM RETAIL PRICE (MRP)', bold: true),
    ]),
  );
  blocks.add(const LetterBlock.spacer());

  blocks.add(
    LetterBlock.plain(LetterBlockKind.body, 'To Whom It May Concern,'),
  );
  blocks.add(const LetterBlock.spacer());

  blocks.add(
    LetterBlock.plain(
      LetterBlockKind.body,
      'We hereby declare that the Maximum Retail Price (MRP) as printed on the '
      'product label and/or packaging for the following product(s) offered in '
      'response to the Government e-Marketplace (GeM) bid/procurement is as '
      'stated below:',
    ),
  );
  blocks.add(const LetterBlock.spacer());

  for (int i = 0; i < input.products.length; i++) {
    final p = input.products[i];
    blocks.add(
      LetterBlock.table(
        tableHeaders: ['Product Name', 'Brand', 'Model No.', 'MRP (₹)'],
        tableRows: [
          [p.productName, p.brandName, p.modelNo, p.mrp],
        ],
      ),
    );
    if (p.imageBytes != null) {
      blocks.add(LetterBlock.productImage(p.imageBytes));
    }
    if (i < input.products.length - 1) {
      blocks.add(const LetterBlock.spacer());
    }
  }

  blocks.add(const LetterBlock.spacer());

  blocks.add(
    LetterBlock.plain(
      LetterBlockKind.body,
      'We hereby solemnly declare and confirm that:',
    ),
  );
  blocks.add(
    LetterBlock.plain(
      LetterBlockKind.body,
      '1. The MRP mentioned above is the Maximum Retail Price as printed on the '
      'product and/or its packaging, inclusive of all applicable taxes.',
    ),
  );
  blocks.add(
    LetterBlock.plain(
      LetterBlockKind.body,
      '2. The price quoted in our GeM bid does not exceed the above-declared MRP '
      'of the product.',
    ),
  );
  blocks.add(
    LetterBlock.plain(
      LetterBlockKind.body,
      '3. We understand that any misrepresentation of the MRP will render our bid '
      'liable to disqualification and may result in debarment from the GeM portal.',
    ),
  );
  blocks.add(const LetterBlock.spacer());

  blocks.add(
    LetterBlock.plain(
      LetterBlockKind.body,
      'We undertake full responsibility for the accuracy of the above declaration '
      'and confirm compliance with the applicable provisions of law and GeM portal '
      'guidelines.',
    ),
  );
  blocks.add(const LetterBlock.spacer());

  blocks.add(LetterBlock.plain(LetterBlockKind.body, 'Yours faithfully,'));
  blocks.add(const LetterBlock.spacer()); // gap for actual signature
  blocks.add(
    LetterBlock.plain(LetterBlockKind.signature, 'Authorization Signatory'),
  );

  return blocks;
}
