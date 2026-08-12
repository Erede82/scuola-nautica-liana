import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/extra_content_ids.dart';
import 'package:scuola_nautica_liana/data/extra_bundle_catalog.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/management_repository_mock.dart';

void main() {
  test(
    'revoking the complete course revokes all included extra products',
    () async {
      final repository = ManagementRepositoryMock();

      await repository.grantStudentExtraProductAccess(
        studentId: 'student-1',
        productId: ExtraContentIds.extraPacchetto,
      );

      expect(
        await repository.listPurchasedExtraProductIds('student-1'),
        containsAll(<String>[
          ExtraContentIds.extraPacchetto,
          ...ExtraBundleCatalog.bundleIncludedProductIds,
        ]),
      );

      await repository.revokeStudentExtraProductAccess(
        studentId: 'student-1',
        productId: ExtraContentIds.extraPacchetto,
      );

      expect(
        await repository.listPurchasedExtraProductIds('student-1'),
        isEmpty,
      );
    },
  );
}
