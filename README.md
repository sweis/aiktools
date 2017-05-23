aiktools
========

This is a clone of the Attestation Identity Key (AIK) tools _previously found_ at http://privacyca.com/code.html (the domain appears to have been purchased by a completely unrelated entity as of May 2017)

This requires:
* A TPM
* apt-get install trousers tpm-tools libtspi-dev


# Documentation

The following documentation was previously found at http://privacyca.com/code.html (grabbed from a 2013 Wayback Machine snapshot); it may be helpful in understanding the code in this repository:


## Sample Source Code

The code samples here are based on the Trousers TPM Software Stack for Linux systems. The following programs are available:

- Privacy CA client
- EK Certificate Extractor
- AIK Direct Proof Utilities
- AIK Quote Utilities


### Privacy CA client

`identity.c` acts as a client to commuicate with the Privacy CA server. It creates an AIK and requests an AIK certificate from the server. (Note: the UI was changed in late 2009 for identity.c to output the AIK as a blob rather than storing it in the TSS database. The previous version is available as identity10.c.)

The program can run in two modes. For the default, insecure mode, compile with:

```
gcc -o identity identity.c -lcurl -ltspi
```

This will create a dummy EK certificate and request a Level 0 AIK certificate from the server. Privacy CA will not attempt to check that the EK is valid and will issue a certificate using its insecure key. This mode is suitable for testing but does not offer verifiers any reason to assume that the AIK is a valid TPM key.

For the secure mode, the TPM must have come with an EK certificate from the manufacturer. At the time of writing, only Infineon TPMs come with such certificates. See the getcert program below for how to extract the EK certificate from the TPM's nonvolatile memory storage, and how to configure Trousers to use the EK certificate. Once this is set up, compile with:

```
gcc -DREALEK -o identity identity.c -lcurl -ltspi
```

This will create a version of the client software that sends the actual EK certificate to the Privacy CA server, and receives a level 1 secure AIK certificate back. This provides verifiers with assurance that the AIK is a valid TPM key and that signatures and Quote operations performed by the AIK represent the actual state of the TPM system.

Run the program as:

```
./identity [-p password] label outkeyblobfile outcertfile
```

Optionally specify "-p password" to create the new AIK using that password for authorization; otherwise it will be a no-auth key. label is a string of the user's choice which is placed into the issued AIK certificate. Two files are output. outkeyblobfile stores the resulting AIK in TCG key blob format. outcertfile holds the AIK certificate issued by Privacy CA.

To use the Quote utilities below, the following OpenSSL command will create a file holding the AIK extracted from the certificate as an RSA public key file:

```
openssl x509 -in certfile -noout -pubkey > rsakeyfile
```

The resulting rsakeyfile holds the AIK public key and can be used to verify issued Quotes.

### EK Certificate Extractor

getcert.c reads the Endorsement Key Certificate from the TPM, if present, and stores it in a file. Compile with:

```
gcc -o getcert getcert.c -ltspi
```

Run it as:

```
./getcert certfilename
```

This will read the certificate from the TPM NV memory and output it to the specified file. Usually it will need TPM owner authentication to read the data. As written, the program uses the Trousers "popup" functionality to read the TPM owner auth, which assumes that the TPM owner password is specified in Unicode. It should be trivial to alter the program to specify the owner auth in the source code, or read it from a environment variable, if that is preferred.

Once the EK certificate is successfully read, it would be a good idea to inspect the cert using a command like:

```
openssl x509 -text -inform DER -in certfilename
```

Note that OpenSSL slightly chokes on EK certificates because TCG specifies an unusual format for the key data, but for the most part this should output some readable data.

To configure Trousers to use the EK certificate, edit its tcsd.conf file (usually in /usr/local/etc) and change the line reading:

```
endorsement_cred =
```
to:

```
endorsement_cred = certfilename
```

where certfilename is the permanent home of the EK cert file. A good location would be in /usr/local/etc alongside tcsd.conf.
Setting up Trousers like this should allow the Privacy CA client software to communicate with the server in secure mode and receive AIK certificates which validate that an AIK is managed by a valid TPM.

### AIK Direct Proof Utilities

aikutils.tgz is a package of files designed to allow systems to directly prove to one another that they possess valid AIKs, without the use of Privacy CA. This may be suitable for applications where client anonymity is not important (such as where systems know each others' IP addresses) and the use of an intermediary like Privacy CA is undesirable.

It is hard to anticipate all the different use cases and security requirements which may be useful in implementing Trusted Computing. These tools represent one possible set of functions. Developers may wish to pursue different directions for their applications but these programs may offer a useful starting point.

These utilities provide a challenge-and-response mechanism allowing a system to prove that it has a valid (TPM-controlled) AIK. First that system creates the AIK and a "proof" file which includes the AIK and the EK certificate. This may be published and made available to other systems which may wish to verify that the claimed AIK is TPM controlled. A system which wants to challenge that claim uses the proof file to encrypt some secret message. This encrypted message gets sent to the system with the AIK. That system runs a third program to decrypt the message, and returns the decrypted data to the challenger. The fact that the decryption was successful proves to the challenger that the AIK is controlled by a valid TPM.

The programs assume that the system wishing to prove it has a valid AIK also has an EK certificate, and that there exists a certificate chain validating that EK certificate which terminates ultimately in a special root certification key. This root certification key is issued and controlled by Verisign, the widely used and trusted CA for much internet commerce. At present, Verisign has certified keys controlled by Infineon. Infineon uses these keys to issue the EK certificates in their TPMs. Hence these utilities are only useful with Infineon TPMs, at the time of writing.

Before using the software, the system which will create the AIK must assemble the necessary collection of certificates for proving its validity. One of these is the EK certificate itself, which may be extracted using the getcert utility on this page. The other certificates must be found on the Infineon web site. Inspect the EK certificate using OpenSSL or similar tools, to determine the Issuer of that certificate. Then examine the certs available from Infineon and find one whose Subject name matches the Issuer of the EK cert. Continue this process recursively, looking for an Infineon cert whose Subject matches the Issuer of the previously found cert, until you find an Infineon certificate whose Issuer is Verisign. This is the certificate chain which will validate the EK certificate and ultimately therefore the AIK.

Extract the files and then compile with:

```
gcc -o aikpublish aikpublish.c -ltspi
gcc -o aikrespond aikrespond.c -ltspi
gcc -o aikchallenge aikchallenge.c vcc_ossl.c -lcrypto
```

On the system which will create the AIK, run:

```
./aikpublish [-p password] ekcertfile [certfiles ...] outprooffile outaikblobfile
```

This program generates a new AIK and associated data. The "-p password" is optional and if specified will use the specified password as the auth value for the newly created AIK. Otherwise the AIK will be no-auth. ekcertfile is the EK certificate; certfiles are the certificates from Infineon which terminate in the Verisign-signed cert. They should be in the order where the first signs the EK cert, each following one signs the one before, and the last is signed by Verisign.
Two output files are created. The first is the "proof" file which includes the public part of the AIK, the EK certificate and the other certificates. This is the file which may be published or sent to the systems which want to verify the claim that the AIK is valid. The second is a file for local storage which holds the newly created AIK in the format of a TCG "blob". This may be loaded into the TPM by other software for subsequent use of the AIK.

Once this step is done, on a system which wants to challenge the claimed validity of the AIK, run:

```
./aikchallenge secretfile aikprooffile outchallengefile outrsafile
```

This takes two input files. secretfile contains secret data which will be encrypted, and whose successful decryption will prove that the AIK is valid. aikprooffile is the published output file from aikpublish. The program validates the aikprooffile, testing the certificate chain for cryptographic validity, and verifying that the final certificate is signed by the Verisign root key. If these tests are successful, it produces its output. The two output files are outchallengefile, which holds the encrypted secret data and which should be sent to the AIK system, and outrsafile which holds the AIK in the form of an OpenSSL RSA public key data structure, suitable for reading with PEM_read_RSA_PUBKEY, which may be useful for verifying subsequent cryptographic signatures issued by the AIK, once it is validated.

The output challenge file should be sent to the system that created the AIK. There, run:

```
./aikrespond [-p password] aikblobfile challengefile outresponsefile
```
The "-p password" should be given if the AIK was created with a password. aikblobfile was output by aikpublish, and challengefile is the file received from the system issuing the challenge. outresponsefile is the decrypted secret data from the challenger.

This should be sent back to the challenger, who compares it with his secret data file. If they match, that proves that the AIK is controlled by a valid TPM. Once these steps are completed, the verifier can remember that the AIK is valid, and use the RSA format file to verify future Quote and Certify operations by the AIK, knowing that it is protected by the TPM and will follow the specified rules.

### AIK Quote Utilities

aikquote.tgz contains two files which demonstrate the use of the TPM's Quote functionality, and verifying the Quote. Quote is used to sign a set of PCR values, in this case using an AIK. If the AIK is genuine and controlled by the TPM, it will only sign true and correct PCR values, which (depending on the system design) may therefore be taken to accurately represent the state of the signing system.

One of the inputs to the Quote operation is an external hash value which is normally assumed to be supplied by the Quote verifier in advance. By including this value in the Quote signature, the verifier knows that the Quote is fresh and is not a replay of an old Quote value. These programs support this function by means of an optional "challengefile" which is assumed to have been provided to the Quote signer in advance by the verifier. The file is SHA1 hashed and that hash is used as the external input to Quote. If the challengefile is not used, the external hash value will be assumed to be 20 bytes of zeros.

Extract the files and then compile with:

```
gcc -o aikquote aikquote.c -ltspi
gcc -o aikqverify aikqverify.c -lcrypto
```

On the system which will issue the Quote, run:

```
./aikquote [-p password] [-c challengefile] aikblobfile pcrnum [pcrnum...] outquotefile
```

This program performs a Quote operation, signing a specified set of PCRs and outputing the result. The optional "-p password" should be given if the AIK was created with a password. Likewise "-c challengefile" is optional and provides the external hash value for Quote, as discussed above. aikblobfile holds the AIK in TCG blob format. This is followed by the numbers of the PCRs which should be signed in this Quote operation. Finally the outquotefile will be output to hold two things: the signed PCR values as a serialized TPM_PCR_COMPOSITE structure; followed by the public key signature that is the result of the Quote.

This output file may be sent to the verifier, who should run:
```
./aikqverify [-c challengefile] aikrsafile quotefile
```

Here, as with aikquote, the "-c challengefile" is optional and should be used if the verifier had sent data in advance to the creator of the Quote to verify freshness. aikrsafile should hold the AIK public key in the format of an OpenSSL RSA public key data structure, such as is output by aikchallenge.c or the openssl command shown with the identity.c programs above; and quotefile is the output from aikquote.

If the Quote signature verifies correctly, aikqverify prints out the PCR numbers and their hex values, and returns a success code of zero. If the Quote signature does not verify, the program prints an error message and returns a nonzero result to indicate error.
