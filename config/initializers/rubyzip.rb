# rubyzip 3 écrit par défaut des en-têtes Zip64 (« version 4.5 requise ») sur chaque fichier de l'archive.
# Word 2007, qui ouvre les .docx au double-clic chez Cyrille, ne lit pas le Zip64 et déclare le document
# « corrompu » (06/10/2026) ; Word 2016 l'accepte, d'où le piège. Les .docx du Studio font quelques
# kilo-octets : le Zip64 n'y sert à rien. Voir GenerationDocx et generation_docx_test.rb.
Zip.write_zip64_support = false
