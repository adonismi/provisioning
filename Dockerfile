FROM openjdk:8
ADD target/petclinic.jar petclinic.jar
ENTRYPOINT ["java", "-jar", "petclinic.jar"]


